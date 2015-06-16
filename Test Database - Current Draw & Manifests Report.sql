

SELECT *
FROM (
	SELECT DRAWDATE, COUNT(*) AS [DRAWCOUNT], SUM(DRAWAMOUNT) AS [DRAWTOTAL]
	FROM SCDRAWS
	GROUP BY DRAWDATE
	) AS D
JOIN (
	SELECT MANIFESTDATE, COUNT(*) AS [MANIFESTCOUNT]
	FROM SCMANIFESTS
	GROUP BY MANIFESTDATE

	) AS M
ON D.DRAWDATE = M.MANIFESTDATE
ORDER BY 1 DESC