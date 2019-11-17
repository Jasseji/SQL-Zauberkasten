#!/bin/bash
#
# Thorsten Bruhns (Thorsten.Bruhns@opitz-consulting.de)
#
# Version: 5
# Date: 17.11.2019

check_env() {
    which whiptail > /dev/null || return 1
    DIALOG=$(which dialog 2>/dev/null || which whiptail 2>/dev/null)
}

set_ora_env() {
    ORACLE_SID="$1"
    # we need this parameter for RAC where oratab has DB_NAME as entry
    ORACLE_SID2="${2:-$1}"
    old_ORAENV_ASK=$ORAENV_ASK
    ORAENV_ASK=NO
    export ORAENV_ASK ORACLE_SID
    . oraenv > /dev/null
    ORAENV_ASK=$old_ORAENV_ASK

    # shellcheck disable=SC2153
    SQLPLUS="$ORACLE_HOME/bin/sqlplus"
    ORA_VERSION=$("$SQLPLUS" -V | cut -d" " -f3)

    export ORACLE_SID="$ORACLE_SID2"
    # shellcheck disable=SC2140
    export PS1="[\u@\h \W] (oenv) ("\$\{ORACLE_SID\}") \$ "
    echo "Starting new bash with Environment for ORACLE_SID: $ORACLE_SID"
    echo "(oenv) in bash prompt indicates a running bash from oenv.sh. Type exit for leaving."
    echo "Version:    $ORA_VERSION (sqlplus -V)"
    echo "ORACLE_HOME: $ORACLE_HOME"
    echo "ORACLE_SID : $ORACLE_SID"
    bash
}

check_sid() {
    # return 0 when valid oratab entry is found
    # we expect a spfile or pfile for the entry
    local sid=$1
    # local rac_option=${2:-0}
    test -f "$oracle_home/dbs/init${sid}.ora" && return 0
    test -f "$oracle_home/dbs/spfile${sid}.ora" && return 0

    # check for an alternative SID
    # RAC has DB_NAME in oratab
    # todo! This need to be fixed for 19c, due to missing
    # spfile from ORACLE_HOME
    # shellcheck disable=SC2046,2086
    for filename in $(basename $(ls $ORACLE_HOME/dbs/spfile${1}[1-8].ora $ORACLE_HOME/dbs/init${1}[1-8].ora 2> /dev/null) 2>/dev/null) ; do
        # extract number from init<sid><number>.ora
        sidfn=$(echo $filename | cut -d"." -f1 )
        sidnr=${sidfn:${#sidfn}-1}
        # is the calculated sid in oratab existing?
        grep "^${sid}${sidnr}:" $oratab >/dev/null 2>&1
        if [ $? -eq 0 ] ; then
            # we found an entry
            # => ignore the calculated value, otherwise a duplicated entry in menu could be created
            return 99
        fi
        return ${sidnr}
    done

    return 99
}

do_sid() {
    oratab=/etc/oratab
    whipsidlist=""

    test -f $oratab || exit 0

    OCRLOC=/etc/oracle/ocr.loc
    if [ -f $OCRLOC ]
    then
        # we have RAC/Restart environment!
        . $OCRLOC
        . /etc/oracle/olr.loc
        # shellcheck disable=SC2154
        SRVCTL="$crs_home/bin/srvctl"
        dbs=$("$crs_home/bin/crsctl" stat res -w "TYPE = ora.database.type" | grep "^NAME" | cut -d"." -f2)

        # add entry for ASM
        # todo!
        # shellcheck disable=SC2002
        asmline=$(cat /etc/oratab | grep "^+ASM")
        # shellcheck disable=SC2086
        sid=$(echo $asmline | cut -d":" -f1)
        oracle_home=$(echo "$asmline" | cut -d":" -f2)
        # shellcheck disable=SC2027
        whipsidlist=${whipsidlist}" "$sid" "$oracle_home" "

        for database in $dbs ; do

            IFS=
            # shellcheck disable=SC2086
            srvctlout="$($SRVCTL config database -d ${database})"
            sid=$(echo "${srvctlout}" | grep "^Database instance:" | tr -d ' ' | cut -d":" -f2)
            oracle_home=$(echo "${srvctlout}" | grep "^Oracle home:" | cut -d":" -f2)

            unset IFS
            # shellcheck disable=SC2027
            whipsidlist=${whipsidlist}" "$sid" "$oracle_home" "
        done
        
    else
        # single isntance without Restart
        # todo!
        # shellcheck disable=SC2013,SC2002
        for sidentry in $(cat "$oratab" | grep -v ^# | grep -v "^\-MGMTDB:" | sort -u)
        do
            sid=$(echo "$sidentry" | cut -d":" -f1)
            oracle_home=$(echo "$sidentry" | cut -d":" -f2)

            # shellcheck disable=SC2016
            UNIX95=true ps -ef | awk '{print $NF}' | grep -E '^asm_pmon_${sid}|^ora_pmon_${sid}|^xe_pmon_XE' > /dev/null 2>&1
            if [ $? -eq 0 ] ; then
                state="up___"
            else
                state="down_"
            fi

            check_sid "$sid" "$oracle_home"
            retcode=$?
            if [ $retcode -ne 99 ] ; then
                if [ $retcode -ne 0 ] ; then
                    sid=${sid}${retcode}
                fi
            unset IFS
            # shellcheck disable=SC2027
            whipsidlist=${whipsidlist}" "$sid" "$state""$oracle_home" "
            fi
        done
    fi

    echo "$whipsidlist"
    # shellcheck disable=SC2086
    OPTIONS=$("$DIALOG"  --title "ORACLE_SID selection" --menu "Choose your ORACLE_SID" 15 60 4 $whipsidlist 3>&1 1>&2 2>&3)
    exitstatus=$?

    if [ "$exitstatus" = 0 ]; then
        
        # we need a way back from sid<nr> to <sid> for RAC
        # => is it a created item or a real item from oratab?
        grep "^${OPTIONS}:" "$oratab" >/dev/null 2>&1
        if [ $? -ne 0 ] ; then
            # find the db_name entry
            # shellcheck disable=SC2034
            OPTIONS2=$(grep "^${OPTIONS:0:${#OPTIONS}-1}:" "$oratab" | cut -d":" -f1)
            set_ora_env "$OPTIONS"2 "$OPTIONS"
        else
            set_ora_env "$OPTIONS"
        fi

    else
        echo "You chose cancel."
    fi
}
# shellcheck disable=SC2034
BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

check_env
do_sid
