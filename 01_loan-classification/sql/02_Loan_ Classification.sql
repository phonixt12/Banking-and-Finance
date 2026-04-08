-- ==================================================================================
-- PROC: Overdue Interest Calculation Date
-- Purpose: caculate overdue interest all credit contract based on examination date @NGAY

-- ==================================================================================


-- Crate proc which caculate overdue interest each credit contract based on examination date --
-- If Examination Date is NULL , produce will use current date --
CREATE OR ALTER PROC TINHLAIQUAHANTHEOTUNGHOPDONG 
    @NGAYHIENTAI DATE,  -- Examination Date
	@MHD NVARCHAR(MAX)-- Credit Contract ID
AS
BEGIN
    SET NOCOUNT ON;
	DECLARE @NGAY DATE = DATEADD(DAY,1,@NGAYHIENTAI)
    --------------------------------------------------------------------------------
    -- 1. Khai báo biến và con trỏ
    --------------------------------------------------------------------------------
    

    -- KHÔNG THAY ĐỔI: Khởi tạo con trỏ lấy danh sách mã hợp đồng cần xử lý
    
    --------------------------------------------------------------------------------
    -- 2. Tạo bảng tạm lưu thông tin trả nợ gần nhất
    --------------------------------------------------------------------------------
    CREATE TABLE #NGAYMOINHAT
    (
        [MÃ HÓA ĐƠN]             NVARCHAR(50),
        [KỲ]                     INT,
        [NGÀY TRẢ TIỀN]          DATE,
        [NGÀY CUỐI KỲ]           DATE,
        [SỐ NGÀY QUÁ HẠN]        INT,
        [TIỀN GỐC ĐÃ TRẢ]        NUMERIC(18,0),
        [TIỀN LÃI ĐÃ TRẢ]        NUMERIC(18,0),
        [TỔNG SỐ TIỀN ĐÃ TRẢ]    NUMERIC(18,0),
        [TIỀN GỐC PHẢI TRẢ]     NUMERIC(18,0),
        [TIỀN LÃI PHẢI TRẢ]     NUMERIC(18,0),
        [TỔNG SỐ TIỀN PHẢI TRẢ] NUMERIC(18,0),
        [GỐC QUÁ HẠN]            NUMERIC(18,0),
        [LÃI QUÁ HẠN]            NUMERIC(18,0),
        [SỐ TIỀN QUÁ HẠN]        NUMERIC(18,0)
    );

    --------------------------------------------------------------------------------
    -- 3. Tạo bảng tạm lưu kết quả lãi quá hạn
    --------------------------------------------------------------------------------
    CREATE TABLE #THONGQUAHAN
    (
        [MÃ KHÁCH HÀNG]         NVARCHAR(50),
        [MÃ HÓA ĐƠN]            NVARCHAR(50),
		[KỲ]                     INT,
        [SỐ NGÀY QUÁ HẠN]       INT,
        [TIỀN GỐC PHẢI TRẢ]     NUMERIC(18,0),
        [GỐC QUÁ HẠN]           NUMERIC(18,0),
        [TIỀN LÃI PHẢI TRẢ]     NUMERIC(18,0),
        [LÃI QUÁ HẠN]           NUMERIC(18,0)
    );

    --------------------------------------------------------------------------------
    -- 4. Vòng lặp xử lý từng hợp đồng
    --------------------------------------------------------------------------------
    
   
        -- 4.1. Xác định kỳ cần kiểm tra
        DECLARE @KYKIEMTRA INT = COALESCE(
            (SELECT KY FROM LOP6_KEHOACH WHERE @NGAY BETWEEN NGAYDAUKI AND NGAYCUOIKI AND MAHDTD = @MHD),
            (SELECT MAX(KY)    FROM LOP6_KEHOACH WHERE MAHDTD = @MHD)
        );

        --------------------------------------------------------------------------------
        -- 4.2. Tính dữ liệu trả nợ tích lũy đến kỳ kiểm tra
        --------------------------------------------------------------------------------
        ;WITH PRE_DATA AS
        (
            SELECT 
                DEBID,
                KY,
                NGAYTRA,
                SUM(TRAGOC) OVER (PARTITION BY DEBID,KY ORDER BY NGAYTRA)   AS TRATIENGOC,
                SUM(TRALAI) OVER (PARTITION BY DEBID,KY ORDER BY NGAYTRA)   AS TRATIENLAI,
                ROW_NUMBER() OVER (PARTITION BY DEBID,KY ORDER BY NGAYTRA DESC) AS RANKS
            FROM KHACHHANG_TRANO
            WHERE [DEBID] = @MHD
              AND KY <= @KYKIEMTRA
        )
        INSERT INTO #NGAYMOINHAT
        SELECT
            K.MAHDTD,
            K.KY,
            P.NGAYTRA,
            K.NGAYCUOIKI,
            CASE WHEN DATEDIFF(DAY, K.NGAYCUOIKI, P.NGAYTRA)  > 0 THEN  DATEDIFF(DAY, K.NGAYCUOIKI, P.NGAYTRA) ELSE 0 END          AS [SỐ NGÀY QUÁ HẠN],
			P.TRATIENGOC,
            P.TRATIENLAI,
            P.TRATIENGOC + P.TRATIENLAI,
            K.GOC_PHAITRA,
            K.LAI_PHAITRA,
            K.TONGTIEN,
            K.GOC_PHAITRA - P.TRATIENGOC,
            K.LAI_PHAITRA - P.TRATIENLAI,
            CASE 
                WHEN (P.TRATIENGOC + P.TRATIENLAI) - K.TONGTIEN > 0 THEN 0 
                ELSE (P.TRATIENGOC + P.TRATIENLAI) - K.TONGTIEN 
            END
        FROM LOP6_KEHOACH K
        JOIN PRE_DATA P 
          ON K.MAHDTD = P.DEBID 
         AND K.KY     = P.KY
        WHERE P.RANKS = 1;

		
        --------------------------------------------------------------------------------
        -- 4.3. Khai báo biến tạm cho kỳ trả gần nhất
        --------------------------------------------------------------------------------
        DECLARE @MKH        NVARCHAR(50) = (
            SELECT MA_KHACHHANG 
            FROM HOPDONG_TINDUNG 
            WHERE MA_HOPDONG_TINDUNG = @MHD
        );

        DECLARE @KYTRAGAN    INT = (
            SELECT MAX(KY) 
            FROM KHACHHANG_TRANO 
            WHERE DEBID = @MHD
        );

		INSERT INTO #THONGQUAHAN SELECT @MKH, [MÃ HÓA ĐƠN], [KỲ], [SỐ NGÀY QUÁ HẠN], [TIỀN GỐC ĐÃ TRẢ], [TIỀN LÃI ĐÃ TRẢ], [GỐC QUÁ HẠN], [LÃI QUÁ HẠN] FROM #NGAYMOINHAT WHERE [KỲ] < @KYTRAGAN
		DECLARE @KYKETIEP INT = @KYTRAGAN + 1 
		
		DECLARE @LAISUATQUA  NUMERIC(18,0) = (
            SELECT (LAISUAT * 150) / 100 
            FROM HOPDONG_TINDUNG 
            WHERE MA_HOPDONG_TINDUNG = @MHD
        );

		 DECLARE @KYHAN       INT = (
            SELECT MAX(KY) 
            FROM LOP6_KEHOACH 
            WHERE MAHDTD = @MHD
        );

		 DECLARE @NMN         DATE = (
            SELECT NGAYCUOIKI 
            FROM LOP6_KEHOACH 
            WHERE MAHDTD = @MHD 
              AND KY     = @KYTRAGAN
        );
        DECLARE @GOCQUAHAN   NUMERIC(18,0) = COALESCE((
            SELECT [GỐC QUÁ HẠN] 
            FROM #NGAYMOINHAT 
            WHERE [MÃ HÓA ĐƠN] = @MHD 
              AND [KỲ]         = @KYTRAGAN
        ),(
            SELECT GOC_PHAITRA 
            FROM LOP6_KEHOACH 
            WHERE MAHDTD = @MHD 
              AND KY         = @KYTRAGAN
        )) ;

        DECLARE @LAIQUAHAN   NUMERIC(18,0) = COALESCE((
            SELECT [LÃI QUÁ HẠN] 
            FROM #NGAYMOINHAT 
            WHERE [MÃ HÓA ĐƠN] = @MHD 
              AND [KỲ]         = @KYTRAGAN
        ),(
            SELECT LAI_PHAITRA 
            FROM LOP6_KEHOACH 
            WHERE MAHDTD = @MHD 
              AND KY         = @KYTRAGAN
        ));
        DECLARE @TIENGOC     NUMERIC(18,0) = COALESCE((
            SELECT [TIỀN GỐC PHẢI TRẢ] 
            FROM #NGAYMOINHAT 
            WHERE [MÃ HÓA ĐƠN] = @MHD 
              AND [KỲ]         = @KYTRAGAN
        ),(
            SELECT GOC_PHAITRA 
            FROM LOP6_KEHOACH 
            WHERE MAHDTD = @MHD 
              AND KY         = @KYTRAGAN
        ));
        DECLARE @TIENLAI     NUMERIC(18,0) = COALESCE((
            SELECT [TIỀN LÃI PHẢI TRẢ] 
            FROM #NGAYMOINHAT 
            WHERE [MÃ HÓA ĐƠN] = @MHD 
              AND [KỲ]         = @KYTRAGAN
        ),(
            SELECT LAI_PHAITRA 
            FROM LOP6_KEHOACH 
            WHERE MAHDTD = @MHD 
              AND KY         = @KYTRAGAN
        ))

		INSERT INTO #THONGQUAHAN
        VALUES
        (
            @MKH,
            @MHD,
			@KYTRAGAN,
            -- SỐ NGÀY QUÁ HẠN
            CASE 
                WHEN @KYTRAGAN = @KYHAN AND @GOCQUAHAN >=0 AND @LAIQUAHAN >=0      THEN 0
                WHEN @KYTRAGAN = @KYKIEMTRA THEN 0
                WHEN @KYTRAGAN < @KYKIEMTRA THEN DATEDIFF(DAY,@NMN,@NGAY) 
				

       
            END,
            -- TIỀN GỐC PHẢI TRẢ
            CASE WHEN @KYTRAGAN = @KYHAN AND @GOCQUAHAN =0 AND @LAIQUAHAN =0    THEN 0 
			     WHEN @KYTRAGAN <=   @KYKIEMTRA AND @GOCQUAHAN =0  THEN 0 
			      ELSE @TIENGOC END,
            -- GỐC QUÁ HẠN
            CASE 
			WHEN @KYTRAGAN = @KYKIEMTRA  AND @GOCQUAHAN = 0 AND @LAIQUAHAN = 0  THEN 0
			WHEN @KYTRAGAN = @KYHAN AND @GOCQUAHAN =0 AND @LAIQUAHAN = 0   THEN 0
			 WHEN @KYTRAGAN = @KYHAN AND @GOCQUAHAN > 0  THEN (SELECT  [GỐC QUÁ HẠN]  FROM #NGAYMOINHAT WHERE [KỲ] = @KYTRAGAN AND [MÃ HÓA ĐƠN] = @MHD) * @LAISUATQUA * (SELECT [SỐ NGÀY QUÁ HẠN] FROM #NGAYMOINHAT WHERE [KỲ] = @KYTRAGAN)/36500
			  WHEN @KYTRAGAN <= @KYKIEMTRA  AND @GOCQUAHAN > 0 AND @TIENGOC = @GOCQUAHAN   THEN @TIENGOC * @LAISUATQUA * (SELECT [SỐ NGÀY QUÁ HẠN] FROM #NGAYMOINHAT WHERE [KỲ] = @KYTRAGAN)/36500
			  WHEN @KYTRAGAN <= @KYKIEMTRA  AND @GOCQUAHAN = 0 AND @LAIQUAHAN  > 0  THEN @TIENGOC * (SELECT LAISUAT FROM HOPDONG_TINDUNG WHERE MA_HOPDONG_TINDUNG = @MHD) 
			  WHEN @KYTRAGAN <= @KYKIEMTRA  AND @GOCQUAHAN > 0 AND  @TIENGOC > @GOCQUAHAN  THEN (SELECT  [GỐC QUÁ HẠN]  FROM #NGAYMOINHAT WHERE [KỲ] = @KYTRAGAN AND [MÃ HÓA ĐƠN] = @MHD) * @LAISUATQUA * (SELECT [SỐ NGÀY QUÁ HẠN] FROM #NGAYMOINHAT WHERE [KỲ] = @KYTRAGAN)/36500
			   
			  ELSE 0
			 END,
            -- TIỀN LÃI PHẢI TRẢ
            CASE WHEN @KYTRAGAN = @KYHAN AND @GOCQUAHAN >=0 AND @LAIQUAHAN >=0 AND @KYKETIEP != @KYHAN THEN 0 ELSE @TIENLAI END,
            -- LÃI QUÁ HẠN
            CASE 
			
			WHEN @KYTRAGAN = @KYKIEMTRA  AND @LAIQUAHAN <= 0 THEN 0
			WHEN @KYTRAGAN = @KYHAN AND @LAIQUAHAN =0  THEN 0
			 WHEN @KYTRAGAN = @KYHAN AND @LAIQUAHAN > 0  THEN (SELECT  [LÃI QUÁ HẠN]  FROM #NGAYMOINHAT WHERE [KỲ] = @KYTRAGAN AND [MÃ HÓA ĐƠN] = @MHD) * @LAISUATQUA * (SELECT [SỐ NGÀY QUÁ HẠN] FROM #NGAYMOINHAT WHERE [KỲ] = @KYTRAGAN)/36500
			  WHEN @KYTRAGAN <= @KYKIEMTRA  AND @LAIQUAHAN > 0 AND @TIENLAI = @LAIQUAHAN    THEN @TIENLAI * @LAISUATQUA * (SELECT [SỐ NGÀY QUÁ HẠN] FROM #NGAYMOINHAT WHERE [KỲ] = @KYTRAGAN)/36500
			  WHEN @KYTRAGAN <= @KYKIEMTRA  AND @LAIQUAHAN > 0 AND  @TIENLAI > @LAIQUAHAN  THEN (SELECT  [LÃI QUÁ HẠN]  FROM #NGAYMOINHAT WHERE [KỲ] = @KYTRAGAN AND [MÃ HÓA ĐƠN] = @MHD) * @LAISUATQUA * (SELECT [SỐ NGÀY QUÁ HẠN] FROM #NGAYMOINHAT WHERE [KỲ] = @KYTRAGAN)/36500
			  ELSE 0
			 END
        )

		 WHILE @KYKETIEP <=@KYKIEMTRA
		 BEGIN
        
		SET @NMN         = (
            SELECT NGAYCUOIKI 
            FROM LOP6_KEHOACH 
            WHERE MAHDTD = @MHD 
              AND KY     = @KYKETIEP
        );
        SET @GOCQUAHAN    = COALESCE((
            SELECT [GỐC QUÁ HẠN] 
            FROM #NGAYMOINHAT 
            WHERE [MÃ HÓA ĐƠN] = @MHD 
              AND [KỲ]         = @KYKETIEP
        ),(
            SELECT GOC_PHAITRA 
            FROM LOP6_KEHOACH 
            WHERE MAHDTD = @MHD 
              AND KY         = @KYKETIEP
        )) ;

        SET @LAIQUAHAN    = COALESCE((
            SELECT [LÃI QUÁ HẠN] 
            FROM #NGAYMOINHAT 
            WHERE [MÃ HÓA ĐƠN] = @MHD 
              AND [KỲ]         = @KYKETIEP
        ),(
            SELECT LAI_PHAITRA 
            FROM LOP6_KEHOACH 
            WHERE MAHDTD = @MHD 
              AND KY         = @KYKETIEP
        ));
        SET @TIENGOC      = COALESCE((
            SELECT [TIỀN GỐC PHẢI TRẢ] 
            FROM #NGAYMOINHAT 
            WHERE [MÃ HÓA ĐƠN] = @MHD 
              AND [KỲ]         = @KYKETIEP
        ),(
            SELECT GOC_PHAITRA 
            FROM LOP6_KEHOACH 
            WHERE MAHDTD = @MHD 
              AND KY         = @KYKETIEP
        ));
        SET @TIENLAI      = COALESCE((
            SELECT [TIỀN LÃI PHẢI TRẢ] 
            FROM #NGAYMOINHAT 
            WHERE [MÃ HÓA ĐƠN] = @MHD 
              AND [KỲ]         = @KYKETIEP
        ),(
            SELECT LAI_PHAITRA 
            FROM LOP6_KEHOACH 
            WHERE MAHDTD = @MHD 
              AND KY         = @KYKETIEP
        ));
	   


        --------------------------------------------------------------------------------
        -- 4.4. Tính và chèn kết quả vào bảng #THONGQUAHAN
        --------------------------------------------------------------------------------
        INSERT INTO #THONGQUAHAN
        VALUES
        (
            @MKH,
            @MHD,
			@KYKETIEP,
            -- SỐ NGÀY QUÁ HẠN
            CASE 
				WHEN  @KYKETIEP = @KYHAN AND DATEDIFF(DAY,@NMN,@NGAY) >0  THEN DATEDIFF(DAY,@NMN,@NGAY)
				WHEN @KYKETIEP = @KYHAN AND @GOCQUAHAN >=0 AND @LAIQUAHAN >=0      THEN 0
                WHEN @KYKETIEP = @KYKIEMTRA THEN 0
                WHEN @KYKETIEP < @KYKIEMTRA THEN DATEDIFF(DAY, @NMN, @NGAY)
				

       
            END,
            -- TIỀN GỐC PHẢI TRẢ
             @TIENGOC ,
            -- GỐC QUÁ HẠN
            CASE 
			WHEN  @KYKETIEP = @KYHAN AND DATEDIFF(DAY,@NMN,@NGAY) >0  THEN @TIENGOC * @LAISUATQUA * (DATEDIFF(DAY,@NMN,@NGAY))/36500
			WHEN DATEDIFF(DAY,@NMN,@NGAY) < 0 THEN 0
			WHEN @KYKETIEP = @KYKIEMTRA  THEN 0
			WHEN @KYKETIEP = @KYHAN AND @GOCQUAHAN =0  THEN 0
			  WHEN @KYKETIEP < @KYKIEMTRA  AND @GOCQUAHAN > 0  THEN @TIENGOC * @LAISUATQUA * (DATEDIFF(DAY,@NMN,@NGAY))/36500
			   
			 
			 
			  ELSE 0
			 END,
            -- TIỀN LÃI PHẢI TRẢ
            @TIENLAI,
            -- LÃI QUÁ HẠN
            CASE 
			WHEN  @KYKETIEP = @KYHAN AND DATEDIFF(DAY,@NMN,@NGAY) >0  THEN @TIENLAI * @LAISUATQUA * (DATEDIFF(DAY,@NMN,@NGAY))/36500
			WHEN DATEDIFF(DAY,@NMN,@NGAY) < 0 THEN 0
			WHEN @KYKETIEP = @KYKIEMTRA       THEN 0
			WHEN @KYKETIEP = @KYHAN AND @LAIQUAHAN <=0  THEN 0
			  WHEN @KYKETIEP < @KYKIEMTRA  AND @LAIQUAHAN > 0    THEN @TIENLAI * @LAISUATQUA * (DATEDIFF(DAY,@NMN,@NGAY))/36500
			 
			  ELSE 0
			 END
        );


		      
			  SET @KYKETIEP = @KYKETIEP +1 
		END;

    

    --------------------------------------------------------------------------------
    -- 5. Truy vấn kết quả cuối cùng với phân loại nhóm nợ
    --------------------------------------------------------------------------------
    WITH PRE_DATA AS 
    (
        SELECT 
            [MÃ KHÁCH HÀNG],
            MAX([SỐ NGÀY QUÁ HẠN]) AS [NGÀY],
            -- PHÂN LOẠI NHÓM NỢ
            CASE 
                WHEN MAX([SỐ NGÀY QUÁ HẠN]) < 10    THEN 'Nhom 1 (No du tieu chuan)'
                WHEN MAX([SỐ NGÀY QUÁ HẠN]) BETWEEN 10  AND 90   THEN 'Nhom 2 (No can chu y)'
                WHEN MAX([SỐ NGÀY QUÁ HẠN]) BETWEEN 91  AND 180  THEN 'Nhom 3 (No duoi tieu chuan)'
                WHEN MAX([SỐ NGÀY QUÁ HẠN]) BETWEEN 181 AND 360  THEN 'Nhom 4 (No nghi ngo)'
                WHEN MAX([SỐ NGÀY QUÁ HẠN]) > 360             THEN 'Nhom 5 (No co kha nang mat von)'
                ELSE 'CHUA PHAN LOAI'
            END AS [PHAN LOAI KHACH]
        FROM #THONGQUAHAN
        GROUP BY [MÃ KHÁCH HÀNG]
    )
    SELECT 
        DISTINCT T.[MÃ KHÁCH HÀNG],
		[PHAN LOAI KHACH]
    FROM #THONGQUAHAN T
    LEFT JOIN PRE_DATA P 
      ON T.[MÃ KHÁCH HÀNG] = P.[MÃ KHÁCH HÀNG]
   
		 ;
END;

EXEC TINHLAIQUAHANTHEOTUNGHOPDONG  '2024-12-31', 'CRCT-00028'



