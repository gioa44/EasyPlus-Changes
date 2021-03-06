ALTER VIEW dbo.C_ACCOUNTS AS
SELECT 
	A.ACC_ID,
    A.BRANCH_ID,
    A.ACCOUNT,
    A.ISO,
    A.DEPT_NO,
    A.BAL_ACC_ALT,
    A.ACT_PAS,
    A.IS_OFFBALANCE,
    A.REC_STATE,
    A.DESCRIP,
    A.DESCRIP_LAT,
    A.ACC_TYPE,
    A.ACC_SUBTYPE,
    A.CLIENT_NO,
    A.DATE_OPEN,
    A.PERIOD,
    A.DATE_CLOSE,
    A.TARIFF,
    A.PRODUCT_NO,
    A.MIN_AMOUNT,
    A.MIN_AMOUNT_NEW,
    A.MIN_AMOUNT_CHECK_DATE,
    A.BLOCKED_AMOUNT,
    A.BLOCK_CHECK_DATE,
    A.PROF_LOSS_ACC,
    A.FLAGS,
    A.REMARK,
    A.CODE_PHRASE,
    A.RESPONSIBLE_USER_ID,
    A.BAL_ACC_OLD,
    A.IS_CONTROL,
    A.IS_INCASSO,
    A.UID,
    A.USER_DEF_TYPE,
    A.BAL_ACC2,
    A.BAL_ACC3,
    A.MIN_AMOUNT_CHECK_DATE_NEW,
    A.SEQUESTRATION,
    A.MOF_STATE,
    CAST(A.ACCOUNT AS VARCHAR(22)) AS ACCOUNT_IBAN, -- A.ACCOUNT_IBAN
    A.ACCOUNT_ALIAS,
    A.IBAN_USAGE_TYPE,
    A.CARD_USAGE_TYPE,
    A.TARIFF_NEW,
    A.SALDO,
    A.SHADOW_DBO,
    A.SHADOW_CRO,
    A.SALDO_AVAILABLE,
    A.LAST_OP_DATE,
    A.AMOUNT_KAS_DELTA,
    A.UID2,
	AT.DESCRIP + ' ' + ISNULL(AST.DESCRIP,'') AS ACC_DESCRIP,
	DP.ALIAS AS BRANCH_ALIAS, DP.ALIAS + ': ' + DP.DESCRIP AS BRANCH_NAME,
	CA1.ATTRIB_VALUE AS IS_CONTROL_COMMENT
FROM dbo.ACC_VIEW A (NOLOCK)
	LEFT JOIN dbo.DEPTS DP (NOLOCK) ON DP.DEPT_NO = A.DEPT_NO
	LEFT JOIN dbo.ACC_TYPES AT (NOLOCK) ON AT.ACC_TYPE = A.ACC_TYPE
	LEFT JOIN dbo.ACC_SUBTYPES AST (NOLOCK) ON AST.ACC_TYPE = A.ACC_TYPE AND AST.ACC_SUBTYPE = A.ACC_SUBTYPE
	LEFT JOIN dbo.ACC_ATTRIBUTES CA1 (NOLOCK) ON CA1.ACC_ID = A.ACC_ID AND CA1.ATTRIB_CODE = '$IS_CONTROL_COMMENT'
GO
