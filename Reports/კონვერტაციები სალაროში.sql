DECLARE
	@start_date smalldatetime = '20170701',
	@end_date smalldatetime = '20171231';

SELECT 
	d.REC_ID [საბუთის უნიკალური #],
	CAST(d.DOC_DATE AS date) [საბუთის თარიღი],
	d.DEBIT [დებეტი],
	d.CREDIT [კრედიტი],
	d.AMOUNT [თანხა A],
	d.ISO [ვალუტა A],
	d.AMOUNT1 [თანხა B],
	d.ISO1 [ვალუტა B],
	ISNULL(d.AMOUNT2, 0.0) [საკურსო სხვაობა],
	ISNULL(p.PERSONAL_ID, '-') AS [კლიენტის პ/ნ],
	dbo.clr_ansi_to_unicode(ISNULL(p.FIRST_NAME, '-')) [სახელი],
	dbo.clr_ansi_to_unicode(ISNULL(p.LAST_NAME, '-')) [გვარი],
	dbo.clr_ansi_to_unicode(d.DESCRIP) [დანიშნულება],
	d.RATE_AMOUNT [კურსი],
	(SELECT TOP (1) dc.TIME_OF_CHANGE FROM dbo.DOC_CHANGES dc WHERE dc.DOC_REC_ID = d.REC_ID ORDER BY dc.REC_ID ASC) [ოპერაციის შესრულების დრო]
FROM dbo.DOCS_CONV_KAS d
	LEFT JOIN dbo.DOC_DETAILS_PASSPORTS p (NOLOCK) ON p.DOC_REC_ID = d.REC_ID
WHERE (d.DOC_DATE BETWEEN @start_date AND @end_date) 
	--AND (d.AMOUNT > 1000.0 OR d.AMOUNT1 > 1000.0)
UNION ALL
SELECT
	d.REC_ID [საბუთის უნიკალური #],
	CAST(d.DOC_DATE AS date) [საბუთის თარიღი],
	d.DEBIT [დებეტი],
	d.CREDIT [კრედიტი],
	d.AMOUNT [თანხა A],
	d.ISO [ვალუტა A],
	d.AMOUNT1 [თანხა B],
	d.ISO1 [ვალუტა B],
	ISNULL(d.AMOUNT2, 0.0) [საკურსო სხვაობა],
	ISNULL(p.PERSONAL_ID, '-') AS [კლიენტის პ/ნ],
	dbo.clr_ansi_to_unicode(ISNULL(p.FIRST_NAME, '-')) [სახელი],
	dbo.clr_ansi_to_unicode(ISNULL(p.LAST_NAME, '-')) [გვარი],
	dbo.clr_ansi_to_unicode(d.DESCRIP) [დანიშნულება],
	d.RATE_AMOUNT [კურსი],
	(SELECT TOP (1) dc.TIME_OF_CHANGE FROM dbo.DOC_CHANGES_ARC dc WHERE dc.DOC_REC_ID = d.REC_ID ORDER BY dc.REC_ID ASC) [ოპერაციის შესრულების დრო]
FROM dbo.DOCS_ARC_CONV_KAS d
	LEFT JOIN dbo.DOC_DETAILS_ARC_PASSPORTS p (NOLOCK) ON p.DOC_REC_ID = d.REC_ID
WHERE (d.DOC_DATE BETWEEN @start_date AND @end_date) 
	--AND (d.AMOUNT > 1000.0 OR d.AMOUNT1 > 1000.0)
ORDER BY d.REC_ID ASC