--
-- Thorsten Bruhns (Thorsten.Bruhns@opitz-consulting.de)
-- $Id: log_hist10.sql 60 2010-03-13 11:20:37Z tbr $
--
-- Information from gv$log_history
--
select stamp
      ,sequence#
      ,first_time
      ,resetlogs_change#
      ,to_char(first_change#,'9999999999999') first_change#
      ,thread#
from (select 
            stamp
            ,sequence#
            ,to_char(first_time, 'dd.mm.rr HH24:mi:ss') first_time
            ,resetlogs_change#
            ,first_change#
            ,thread#
        from gv$log_history
       order by RESETLOGS_CHANGE# desc, first_change# desc
     )
where rownum < 100
order by first_change#
;

