SET NOCOUNT ON;
/* 
Check-ები

SELECT COUNT(*) FROM dbo.LOAN_ACCOUNTS
WHERE ACC_ID IN 
(
	SELECT ACC_ID
	FROM dbo.ACCOUNTS
	WHERE BAL_ACC_ALT IN (1905, 1915) --AND CLIENT_NO IS NULL
)

-- შემოწმება 18-ებსა და კლიენტის ტიპებს შორის აცდენების, ისეთ სესხებზე რომლებზეც შეხებას ვაპირებთ (1905, 1915 ანგარიშები ვისაც აქვს გაწერილი)
-- რომ მერე ხელით მივხედოთ
SELECT c.CLIENT_NO, c.CLIENT_TYPE, c.CLIENT_SUBTYPE, l.BAL_ACC, *
FROM dbo.LOAN_ACCOUNTS la
	INNER JOIN dbo.LOANS l ON l.LOAN_ID = la.LOAN_ID
	INNER JOIN dbo.CLIENTS c ON c.CLIENT_NO = l.CLIENT_NO
WHERE la.ACC_ID IN 
(
	SELECT a1.ACC_ID
	FROM dbo.ACCOUNTS a1
	WHERE a1.BAL_ACC_ALT IN (1905, 1915)
)
AND (
	RIGHT(CAST(CAST(l.BAL_ACC AS INT) AS VARCHAR(4)), 1) = '1' AND c.CLIENT_TYPE <> 1 -- 18 აქვს ფიზიკურის, მაგრამ არაა ფიზიკური პირი
	OR RIGHT(CAST(CAST(l.BAL_ACC AS INT) AS VARCHAR(4)), 1) <> '1' AND c.CLIENT_TYPE = 1 -- 18 აქვს იურიდიულის, მაგრამ ფიზიკური პირია
	-- ცვლილებების გადამოწმება (SELECT dbo.clr_ansi_to_unicode(cc.DESCRIP), * FROM dbo.CLI_CHANGES cc WHERE cc.CLIENT_NO = 318)
)
*/


/*
Maia's mapping:

1905		1901	ფიზიკური პირი
1905		1902	იურიდიული პირი
1915		1911	ფიზიკური პირი
1915		1912	იურიდიული პირი
*/

IF NOT EXISTS ( SELECT *  FROM dbo.ACC_ATTRIB_CODES WHERE CODE = 'PREDECESSOR_ACCOUNT')
BEGIN
	INSERT INTO dbo.ACC_ATTRIB_CODES ( CODE, DESCRIP, IS_REQUIRED, ONLY_ONE_VALUE, USAGE_TYPE, TYPE, [VALUES] )
	VALUES
	( 'PREDECESSOR_ACCOUNT', 'ßÉÍÀÌÏÒÁÄÃÉ ÀÍÂÀÒÉÛÉ', 0, 0, 6, 0, NULL ), 
	( 'SUCCESSOR_ACCOUNT', 'ÌÄÌÊÅÉÃÒÄ ÀÍÂÀÒÉÛÉ', 0, 0, 6, 0, NULL )
END
GO

--BEGIN TRANSACTION -- gioa. temp

-- Step 1 ------------------------------------------------------------------------------------------------------------------------------

-- 1905 ფიზიკურ 18-ებზე (უნდა შევცვალოთ 1901)
; WITH t AS
(
	SELECT *
	FROM dbo.LOAN_BAL_ACCS lba
	WHERE lba.ACCOUNT_BAL_ACC = 1905 AND RIGHT(CAST(CAST(lba.BAL_ACC AS INT) AS VARCHAR(4)), 1) = '1'
)
UPDATE t
SET ACCOUNT_BAL_ACC = 1901

-- 1905 იურიდიულ 18-ებზე (უნდა შევცვალოთ 1902)
; WITH t AS
(
	SELECT * 
	FROM dbo.LOAN_BAL_ACCS lba
	WHERE lba.ACCOUNT_BAL_ACC = 1905 AND RIGHT(CAST(CAST(lba.BAL_ACC AS INT) AS VARCHAR(4)), 1) <> '1'
)
UPDATE t
SET ACCOUNT_BAL_ACC = 1902



-- 1915 ფიზიკურ 18-ებზე (უნდა შევცვალოთ 1911)
; WITH t AS
(
	SELECT *
	FROM dbo.LOAN_BAL_ACCS lba
	WHERE lba.ACCOUNT_BAL_ACC = 1915 AND RIGHT(CAST(CAST(lba.BAL_ACC AS INT) AS VARCHAR(4)), 1) = '1'
)
UPDATE t
SET ACCOUNT_BAL_ACC = 1911

-- 1915 იურიდიულ 18-ებზე (უნდა შევცვალოთ 1912)
; WITH t AS
(
	SELECT * 
	FROM dbo.LOAN_BAL_ACCS lba
	WHERE lba.ACCOUNT_BAL_ACC = 1915 AND RIGHT(CAST(CAST(lba.BAL_ACC AS INT) AS VARCHAR(4)), 1) <> '1'
)
UPDATE t
SET ACCOUNT_BAL_ACC = 1912

-- Step 2 ------------------------------------------------------------------------------------------------------------------------------

-- TODO
DECLARE
	@date datetime = '2017-09-23', -- gioa. ამ თარიღის ნაშთი უნდა გადავიტანოთ, ამ თარიღისვე DOC_DATE-ით. ამ თარიღის მერე ანგარიშზე ბრუნვა არ უნდა არსებობდეს ( SELECT MAX(o.DOC_DATE) FROM dbo.OPS_0000 o )
	@loan_id int,
	@balance_on_old_19_acc money,
	@message nvarchar(300)


DECLARE cur1 CURSOR FAST_FORWARD LOCAL READ_ONLY
FOR 
	SELECT -- TOP (10) gioa. temp
		la.LOAN_ID, dbo.acc_get_balance(la.ACC_ID, @date, 0, 0, 0)
	FROM dbo.LOAN_ACCOUNTS la		
		INNER JOIN dbo.LOANS l ON l.LOAN_ID = la.LOAN_ID
	WHERE la.ACC_ID IN 
	(
		SELECT ACC_ID
		FROM dbo.ACCOUNTS
		WHERE BAL_ACC_ALT IN (1905, 1915)
	)
	AND l.[STATE] < 255
	--AND la.LOAN_ID = 5321
	
OPEN cur1

FETCH NEXT FROM cur1 INTO @loan_id, @balance_on_old_19_acc

WHILE @@FETCH_STATUS = 0
BEGIN
	BEGIN TRY
		BEGIN TRANSACTION -- gioa. correct one
	    
	    DECLARE
	    	@loan_iso char(3),
	    	@old_19_acc_id int
	    	
	    SELECT 
	    	@old_19_acc_id = la.ACC_ID,
	    	@loan_iso = l.ISO
	    FROM dbo.LOAN_ACCOUNTS la 
	    	INNER JOIN dbo.LOANS l ON l.LOAN_ID = la.LOAN_ID
	    WHERE la.LOAN_ID = @loan_id AND la.ACCOUNT_TYPE = 40

		SET @message = 'loan_id: ' + CAST(@loan_id AS varchar(20)) + ' old_acc_id: ' + CAST(@old_19_acc_id AS varchar(20))
			+ ' balance: ' + CAST(@balance_on_old_19_acc AS nvarchar(20))

		RAISERROR (@message, 0, 0) WITH NOWAIT
	    
	    IF @balance_on_old_19_acc <> dbo.acc_get_balance(@old_19_acc_id, @date, 0, 0, 2)
	    BEGIN
	    	PRINT 'We have some problem ! loan_id: ' + CAST(@loan_id AS varchar(20))
	    	FETCH NEXT FROM cur1 INTO @loan_id, @balance_on_old_19_acc;
	    	CONTINUE;
	    END
	    
	    DELETE FROM dbo.LOAN_ACCOUNTS WHERE LOAN_ID = @loan_id
	    
	    DECLARE 
	    	@new_19_acc_id INT,
	    	@account TACCOUNT,
	    	@acc_added BIT,
	    	@bal_acc TBAL_ACC;
	    
	    -- რადგან ჩავხსენით, ეს ახალს შექმნის
	    EXEC dbo.LOAN_SP_GET_ACCOUNT 
	    	@acc_id = @new_19_acc_id OUTPUT,
	    	@account = @account OUTPUT,
	    	@acc_added = @acc_added OUTPUT,
	    	@bal_acc = @bal_acc OUTPUT,
	    	@type_id = 40,
	    	@loan_id = @loan_id,
	    	@iso = @loan_iso,
	    	@user_id = 2,
	    	@simulate = 0
	    
	    INSERT INTO dbo.ACC_ATTRIBUTES ( ACC_ID, ATTRIB_CODE, ATTRIB_VALUE )
	    VALUES (
	    		@new_19_acc_id,
	    		'PREDECESSOR_ACCOUNT',
	    		CAST((SELECT a.ACCOUNT FROM dbo.ACCOUNTS a WHERE a.ACC_ID = @old_19_acc_id) AS varchar(20))
	    	),
	    	(
	    		@old_19_acc_id,
	    		'SUCCESSOR_ACCOUNT',
	    		CAST((SELECT a.ACCOUNT FROM dbo.ACCOUNTS a WHERE a.ACC_ID = @new_19_acc_id) AS varchar(20))
	    	)
	    
	    DECLARE
	    	@rec_id int,
	    	@info_message varchar(255)
	    
	    IF @balance_on_old_19_acc > $0
		BEGIN
	    	EXEC dbo.ADD_DOC4
	    		@rec_id=@rec_id OUTPUT,
	    		@user_id=2,
	    		@doc_date=@date,
	    		@iso=@loan_iso,
	    		@amount=@balance_on_old_19_acc,
	    		@rec_state = 20,
	    		@doc_num=314, -- შემთხვევითად შერჩეული
	    		@debit_id=@new_19_acc_id,
	    		@credit_id=@old_19_acc_id,
	    		@op_code = 'MNL19', -- სპეციალურად შერჩეული, მომავალში იდენტიფიცირებისთვის
	    		@descrip='ÍÀÛÈÉÓ ÂÀÃÀÔÀÍÀ 1905,1915 ÀÍÂÀÒÉÛÄÁÉÃÀÍ 1901,1902,1911,1912 ÀÍÂÀÒÉÛÄÁÆÄ',
	    		@parent_rec_id=-1,
	    		@owner=2,
	    		@doc_type=98,
	    		@dept_no=0,
	    		@check_saldo=0,
	    		@info_message=@info_message OUTPUT,
	    		@info=0

		END


	    /*{ ძველი ანგარიშის დახურვა*/
	    	
	    INSERT INTO dbo.ACC_CHANGES (ACC_ID,USER_ID,DESCRIP) 
		VALUES (@old_19_acc_id,2,'MNL19 - ÀÍÂÀÒÉÛÉÓ ÛÄÝÅËÀ : REC_STATE DATE_CLOSE UID')
	    
	    SET @rec_id=SCOPE_IDENTITY()
	    
	    INSERT INTO dbo.ACCOUNTS_ARC 
	    	SELECT @rec_id,* 
	    	FROM ACCOUNTS 
	    	WHERE ACC_ID=@old_19_acc_id
	    
	    UPDATE ACCOUNTS 
	    SET 
	    	REC_STATE=2,
	    	DATE_CLOSE=GETDATE(),
	    	UID=UID+1
	    WHERE ACC_ID=@old_19_acc_id

		/*} ძველი ანგარიშის დახურვა*/

		--ROLLBACK TRANSACTION -- gioa. temp
		COMMIT TRANSACTION -- gioa. correct one
	END TRY
	BEGIN CATCH
	    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; -- gioa. correct one

		SET @message = 'transaction for loan_id: ' + CAST(@loan_id AS varchar(20)) + 'has been rolled back . Error: ' + CHAR(13) + CHAR(10) +
			ERROR_MESSAGE();

		RAISERROR (@message, 0, 0) WITH NOWAIT;
	END CATCH

	FETCH NEXT FROM cur1 INTO @loan_id, @balance_on_old_19_acc
END

CLOSE cur1
DEALLOCATE cur1

GO
--SELECT * FROM dbo.ACC_ATTRIBUTES aa WHERE aa.ATTRIB_CODE LIKE '%ACCOUNT%'
SELECT * FROM dbo.OPS_0000 o 
WHERE 
	o.DEBIT_ID IN (
		SELECT aa.ACC_ID FROM dbo.ACC_ATTRIBUTES aa WHERE aa.ATTRIB_CODE LIKE '%ACCOUNT%'
	)
	OR 
	o.CREDIT_ID IN (
		SELECT aa.ACC_ID FROM dbo.ACC_ATTRIBUTES aa WHERE aa.ATTRIB_CODE LIKE '%ACCOUNT%'
	)


--ROLLBACK TRANSACTION -- gioa. temp


-- DEBUG
	    	--SELECT dbo.acc_get_balance(a.ACC_ID, @date, 0, 0, 0) AS balance, a.*
	    	--INTO #acc1 
	    	--FROM dbo.LOAN_ACCOUNTS la 
	    	--	INNER JOIN dbo.ACCOUNTS a ON a.ACC_ID = la.ACC_ID
	    	--WHERE la.LOAN_ID = @loan_id AND la.ACCOUNT_TYPE = 40
	    
	    	

/*
	    	SELECT dbo.acc_get_balance(42620, '20170901', 0, 0, 0)
	    	--42620, 122972
	    	*/
	    
	    	----Debug
	    	--INSERT INTO #acc1
	    	--SELECT dbo.acc_get_balance(a.ACC_ID, @date, 0, 0, 0) AS balance, a.*
	    	--FROM dbo.ACCOUNTS a 
	    	--WHERE a.ACC_ID = @old_19_acc_id
	    
	    
	    	--INSERT INTO #acc1
	    	--SELECT dbo.acc_get_balance(a.ACC_ID, @date, 0, 0, 0) AS balance, a.*
	    	--FROM dbo.LOAN_ACCOUNTS la 
	    	--	INNER JOIN dbo.ACCOUNTS a ON a.ACC_ID = la.ACC_ID
	    	--WHERE la.LOAN_ID = @loan_id AND la.ACCOUNT_TYPE = 40
	    
	    	--SELECT * FROM #acc1
	    
	    	--SELECT * FROM dbo.ACC_ATTRIBUTES aa WHERE aa.ATTRIB_CODE LIKE '%ACCOUNT%'