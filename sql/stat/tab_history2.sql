--
-- Thorsten Bruhns (Thorsten.Bruhns@opitz-consulting.de)
--
-- Version: 2
--
-- historical statistic information from wri$_optstat_tab_history
-- savetime => Timestamp of inserting the data in data-Dictionary!
--
-- Parameter 1. Owner
-- Parameter 2: Tablename
--
set lines 130
set pages 100
set echo off
set trimspool on

column owner format a20
column table_name format a30
column partition_name format a15

select do.OWNER
      ,do.object_name TABLE_NAME
      ,do.SUBOBJECT_NAME PARTITION_NAME
      ,wot.ROWCNT
      ,wot.BLKCNT
      ,wot.AVGRLN
      ,wot.SAMPLESIZE sample
      ,to_char(wot.SAVTIME, 'dd.MM HH24:MI') Savetime
  from SYS.WRI$_OPTSTAT_TAB_HISTORY wot
  join dba_objects do on do.object_id = wot.obj#
 where do.OWNER like ('&1')
   and do.OBJECT_NAME like ('&2')
order by wot.SAVTIME
;
