/*
	 1. @bal_acc_list-ის ყველა ანგარიშზე ყველა გატარება უნდა იყოს მწვანე
	 2. @date-ის შემდეგ ანგარიშებზე, რომლის ნაშთებიც ამ სკრიფტს გადააქვს (@bal_acc_list), სისტემაში გატარება არ უნდა არსებობდეს
	 3. თუ გვინდა ძველი ანგარიშების დახურვა მოვხსნათ შესაბამისი კომენტი
*/
SET XACT_ABORT, NOCOUNT ON;

IF NOT EXISTS ( SELECT *  FROM dbo.ACC_ATTRIB_CODES WHERE CODE = 'PREDECESSOR_ACCOUNT')
BEGIN
	INSERT INTO dbo.ACC_ATTRIB_CODES ( CODE, DESCRIP, IS_REQUIRED, ONLY_ONE_VALUE, USAGE_TYPE, TYPE, [VALUES] )
	VALUES
	( 'PREDECESSOR_ACCOUNT', 'ßÉÍÀÌÏÒÁÄÃÉ ÀÍÂÀÒÉÛÉ', 0, 0, 6, 0, NULL ), 
	( 'SUCCESSOR_ACCOUNT', 'ÌÄÌÊÅÉÃÒÄ ÀÍÂÀÒÉÛÉ', 0, 0, 6, 0, NULL )
END
GO


DECLARE
	@date datetime = '2017-09-24'

DECLARE
	@bal_acc_list table (old_bal_acc TBAL_ACC, new_bal_acc TBAL_ACC)

INSERT INTO @bal_acc_list 
VALUES (1705, 1703), (1715, 1713), (1704, 1703), (1714, 1713), (1702, 1703), (1712, 1713), (1706, 1703), (1716, 1713)


DECLARE
	@new_acc_template varchar(100) = '{A1}{A2}{A3}{A4}NNNN'
	

DECLARE
	@message nvarchar(max),
	@old_acc_id int,
	@old_bal_acc_alt TBAL_ACC,
	@new_acc_id int,
	@old_acc_balance money,
	@debit_id int,
	@credit_id int,
	@rec_id int,
	@info_message varchar(255),	
	@old_acc_iso char(3),
	@client_type int,
	@old_acc_descrip varchar(100),
	@old_acc_descrip_lat varchar(100),
	@old_acc_acc_type tinyint, 
	@old_acc_acc_subtype int, 
	@old_acc_client_no int,
	@old_acc_act_pas tinyint,
	@new_bal_acc_alt TBAL_ACC


DECLARE cr_name CURSOR FAST_FORWARD LOCAL READ_ONLY
FOR 
	SELECT a.ACC_ID, a.ACT_PAS, a.BAL_ACC_ALT, a.ISO, a.DESCRIP, a.DESCRIP_LAT, a.ACC_TYPE, a.ACC_SUBTYPE, a.CLIENT_NO,
		--c.CLIENT_TYPE, 
		dbo.acc_get_balance(a.ACC_ID, @date, 0, 0, 0) AS old_acc_balance
	FROM dbo.ACCOUNTS a
		--INNER JOIN dbo.CLIENTS c ON c.CLIENT_NO = a.CLIENT_NO
	WHERE a.BAL_ACC_ALT IN (SELECT old_bal_acc FROM @bal_acc_list)

OPEN cr_name

FETCH NEXT FROM cr_name INTO @old_acc_id, @old_acc_act_pas, @old_bal_acc_alt, @old_acc_iso, @old_acc_descrip, @old_acc_descrip_lat,
	@old_acc_acc_type, @old_acc_acc_subtype, @old_acc_client_no,
	--@client_type, 
	@old_acc_balance

WHILE @@FETCH_STATUS = 0
BEGIN
	SET @message = 'processing acc: ' + CAST(@old_acc_id AS varchar(20)) + ' with balance ' + CAST(@old_acc_balance AS varchar(20))
	RAISERROR (@message, 0, 0) WITH NOWAIT;

	BEGIN TRY
	    BEGIN TRANSACTION 
	    
	    SELECT 
	    	@new_bal_acc_alt = b.new_bal_acc
	    FROM @bal_acc_list b
	    WHERE b.old_bal_acc = @old_bal_acc_alt
	    
	    IF @old_acc_balance <> 0
	    BEGIN
	    	DECLARE
	    		@account TACCOUNT
	    
	    	EXEC dbo.GET_NEXT_ACC_NUM_NEW
	    		@bal_acc = @new_bal_acc_alt,
	    		@branch_id = 0,
	    		@dept_no = 0,
	    		@client_no = @old_acc_client_no,
	    		@iso = @old_acc_iso,
	    		@product_no = 0,
	    		@acc = @account OUT,
	    		@template = @new_acc_template,
	    		@user_id = 2,
	    		@return_row = 0;
	    
	    	--SELECT @account;
	    
	    	EXEC dbo.ADD_ACCOUNT
	    		@acc_id			= @new_acc_id OUTPUT,
	    		@user_id		= 2,
	    		@dept_no		= 0,
	    		@account		= @account,
	    		@iso			= @old_acc_iso,
	    		@bal_acc_alt	= @new_bal_acc_alt,
	    		--@rec_state		= @rec_state,
	    		@descrip		= @old_acc_descrip,
	    		@descrip_lat	= @old_acc_descrip_lat,
	    		@acc_type		= @old_acc_acc_type, 
	    		@acc_subtype	= @old_acc_acc_subtype, 
	    		@client_no		= @old_acc_client_no,
	    		@date_open		= @date,
	    		@flags			= 0

			INSERT INTO dbo.ACC_ATTRIBUTES ( ACC_ID, ATTRIB_CODE, ATTRIB_VALUE )
			VALUES (
	    			@new_acc_id,
	    			'PREDECESSOR_ACCOUNT',
	    			CAST((SELECT a.ACCOUNT FROM dbo.ACCOUNTS a WHERE a.ACC_ID = @old_acc_id) AS varchar(20))
	    		),
	    		(
	    			@old_acc_id,
	    			'SUCCESSOR_ACCOUNT',
	    			CAST((SELECT a.ACCOUNT FROM dbo.ACCOUNTS a WHERE a.ACC_ID = @new_acc_id) AS varchar(20))
	    		)
	    END            
	    
	    
	    IF @old_acc_balance > 0
	    BEGIN
			EXEC dbo.ADD_DOC4
	    		@rec_id=@rec_id OUTPUT,
	    		@user_id=2,
	    		@doc_date=@date,
	    		@iso=@old_acc_iso,
	    		@amount=@old_acc_balance,
	    		@rec_state = 20,
	    		@doc_num=315, -- შემთხვევითად შერჩეული
	    		@debit_id=@new_acc_id,
	    		@credit_id=@old_acc_id,
	    		@op_code = 'MNL17', -- სპეციალურად შერჩეული, მომავალში იდენტიფიცირებისთვის
	    		@descrip='ÍÀÛÈÉÓ ÂÀÃÀÔÀÍÀ 17 ÊËÀÓÉÓ ÀÍÂÀÒÉÛÄÁÓ ÛÏÒÉÓ (ÃÀÃÄÁÉÈÉ ÁÀËÀÍÓÉ)', --gioa
	    		@parent_rec_id=-1,
	    		@owner=2,
	    		@doc_type=98,
	    		@dept_no=0,
	    		@check_saldo=0,
	    		@info_message=@info_message OUTPUT,
	    		@info=0
	    END
	    ELSE
	    IF @old_acc_balance < 0
	    BEGIN
	    	SET @old_acc_balance = -@old_acc_balance
	    	EXEC dbo.ADD_DOC4
	    		@rec_id=@rec_id OUTPUT,
	    		@user_id=2,
	    		@doc_date=@date,
	    		@iso=@old_acc_iso,
	    		@amount=@old_acc_balance,
	    		@rec_state = 20,
	    		@doc_num=315, -- შემთხვევითად შერჩეული
	    		@debit_id=@old_acc_id,
	    		@credit_id=@new_acc_id,
	    		@op_code = 'MNL17', -- სპეციალურად შერჩეული, მომავალში იდენტიფიცირებისთვის
	    		@descrip='ÍÀÛÈÉÓ ÂÀÃÀÔÀÍÀ 17 ÊËÀÓÉÓ ÀÍÂÀÒÉÛÄÁÓ ÛÏÒÉÓ (ÖÀÒÚÏ×ÉÈÉ ÁÀËÀÍÓÉ)', --gioa
	    		@parent_rec_id=-1,
	    		@owner=2,
	    		@doc_type=98,
	    		@dept_no=0,
	    		@check_saldo=0,
	    		@info_message=@info_message OUTPUT,
	    		@info=0
	    END

		/*{ ძველი ანგარიშის დახურვა*/
	    	
	 --   INSERT INTO dbo.ACC_CHANGES (ACC_ID,USER_ID,DESCRIP) 
		--VALUES (@old_acc_id ,2,'MNL17 - ÀÍÂÀÒÉÛÉÓ ÛÄÝÅËÀ : REC_STATE DATE_CLOSE UID')
	    
	 --   SET @rec_id=SCOPE_IDENTITY()
	    
	 --   INSERT INTO dbo.ACCOUNTS_ARC 
	 --   	SELECT @rec_id,* 
	 --   	FROM ACCOUNTS 
	 --   	WHERE ACC_ID=@old_acc_id
	    
	 --   UPDATE ACCOUNTS 
	 --   SET 
	 --   	REC_STATE=2,
	 --   	DATE_CLOSE=GETDATE(),
	 --   	UID=UID+1
	 --   WHERE ACC_ID=@old_acc_id

		/*} ძველი ანგარიშის დახურვა*/
	    
	    COMMIT TRANSACTION 
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; -- gioa. correct one

		SET @message = 'transaction for acc_id: ' + CAST(@old_acc_id AS varchar(20)) + ' has been rolled back . Error: ' + CHAR(13) + CHAR(10) +
			ERROR_MESSAGE();

		RAISERROR (@message, 0, 0) WITH NOWAIT;
	END CATCH

	FETCH NEXT FROM cr_name INTO @old_acc_id, @old_acc_act_pas, @old_bal_acc_alt, @old_acc_iso, @old_acc_descrip, @old_acc_descrip_lat,
		@old_acc_acc_type, @old_acc_acc_subtype, @old_acc_client_no,
		--@client_type, 
		@old_acc_balance

END

CLOSE cr_name
DEALLOCATE cr_name
GO