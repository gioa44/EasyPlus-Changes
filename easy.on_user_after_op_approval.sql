CREATE PROCEDURE easy.on_user_after_op_approval
	@loan_id int,
	@op_id int,
	@user_id int
AS
BEGIN
	IF EXISTS (
		SELECT *
		FROM dbo.LOANS l
			INNER JOIN dbo.LOAN_PRODUCT_ATTRIBUTES pa ON pa.PRODUCT_ID = l.PRODUCT_ID
				AND pa.ATTRIB_CODE = 'PenaltyOnPrincipal' AND pa.ATTRIB_VALUE = '1'
		WHERE l.LOAN_ID = @loan_id 
	)
	BEGIN
		INSERT INTO dbo.LOAN_ATTRIBUTES ( LOAN_ID, ATTRIB_CODE, ATTRIB_VALUE )
		VALUES ( @loan_id, 'PenaltyOnPrincipal', '1' )
	END

	RETURN (0);
END
GO