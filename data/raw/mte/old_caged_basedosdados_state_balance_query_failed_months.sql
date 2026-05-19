SELECT
  ano,
  mes,
  sigla_uf,
  SUM(saldo_movimentacao) AS formal_hiring_balance,
  COUNT(*) AS n_records
FROM `basedosdados.br_me_caged.microdados_antigos`
WHERE (ano = 2008 AND mes = 5)
  OR (ano = 2008 AND mes = 8)
  OR (ano = 2009 AND mes = 6)
  OR (ano = 2009 AND mes = 8)
  OR (ano = 2009 AND mes = 10)
  OR (ano = 2009 AND mes = 11)
  OR (ano = 2010 AND mes = 5)
  OR (ano = 2010 AND mes = 6)
  OR (ano = 2010 AND mes = 7)
  OR (ano = 2010 AND mes = 10)
  OR (ano = 2010 AND mes = 12)
  OR (ano = 2011 AND mes = 3)
  OR (ano = 2012 AND mes = 5)
  OR (ano = 2012 AND mes = 6)
  OR (ano = 2012 AND mes = 8)
  OR (ano = 2012 AND mes = 10)
  OR (ano = 2013 AND mes = 1)
  OR (ano = 2013 AND mes = 10)
  OR (ano = 2014 AND mes = 3)
  OR (ano = 2014 AND mes = 5)
  OR (ano = 2014 AND mes = 9)
  OR (ano = 2014 AND mes = 12)
  OR (ano = 2015 AND mes = 1)
  OR (ano = 2015 AND mes = 3)
  OR (ano = 2015 AND mes = 7)
  OR (ano = 2015 AND mes = 11)
  OR (ano = 2016 AND mes = 3)
  OR (ano = 2016 AND mes = 5)
  OR (ano = 2017 AND mes = 4)
  OR (ano = 2017 AND mes = 6)
  OR (ano = 2017 AND mes = 12)
  OR (ano = 2019 AND mes = 1)
  OR (ano = 2019 AND mes = 3)
  OR (ano = 2019 AND mes = 8)
  OR (ano = 2019 AND mes = 9)
GROUP BY ano, mes, sigla_uf
ORDER BY ano, mes, sigla_uf
