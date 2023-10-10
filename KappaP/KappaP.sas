/*
===================================
Macro Name: KappaP
Macro Label: Kappa ϵ���ļ���Pֵ
Author: wtwang
Version Date: 2023-01-13 V1.0
===================================
*/

%macro KappaP(INDATA, TABLE_DEF, OUTDATA, STAT_NOTE = %str(Kappa Pֵ), WEIGHT = #NULL, KAPPA_TYPE = #SIMPLE, KAPPA_WEIGHT = #AUTO,
              EXACT = FALSE, NULL_KAPPA = #AUTO, SIDES = 2, FORMAT = PVALUE6.3, PLACEHOLDER = %str(-), DEL_TEMP_DATA = TRUE) /des = "Kappa ϵ�������Pֵ" parmbuff;
/*
INDATA:          �������ݼ�����
TABLE_DEF:       R*C��Ķ���
STAT_NOTE:       ͳ����������, ���磺STAT_NOTE = %str(Kappa Pֵ)
OUTDATA:         ������ݼ�����
WEIGHT:          Ȩ�ر���
KAPPA_TYPE:      Kappaֵ�����ͣ���Kappa, ��ȨKappa��
KAPPA_WEIGHT:    KappaȨ�ص����ͣ�Cicchetti-Allison, Fleiss-Cohen��
EXACT:           �Ƿ���о�ȷ����
NULL_KAPPA:      ������µ�Kappaϵ��
SIDES:           �������ͣ�1: �������, 2: ˫����飩
PLACEHOLDER:     ռλ��������Ϊ�ջ�����ϡ��ʱ���޷�����Kappaֵ�����ռλ�������ݼ���
DEL_TEMP_DATA:   ɾ���м����ݼ�
*/

    /*�򿪰����ĵ�*/
    %if %qupcase(%superq(SYSPBUFF)) = %bquote((HELP)) or %qupcase(%superq(SYSPBUFF)) = %bquote(()) %then %do;
        %let host = %bquote(192.168.0.199);
        %let help = %bquote(\\&host\ͳ�Ʋ�\SAS��\08 FreqStatKit\05 �����ĵ�\KappaP\readme.html);
        %if %sysfunc(system(ping &host -n 1 -w 10)) = 0 %then %do;
            %if %sysfunc(fileexist("&help")) %then %do;
                X explorer "&help";
            %end;
            %else %do;
                X mshta vbscript:msgbox("�����ĵ�������, Ŀ���ļ������ѱ��ƶ���ɾ����Orz",48,"��ʾ")(window.close);
            %end;
        %end;
        %else %do;
                X mshta vbscript:msgbox("�����ĵ�������, ��Ϊ�޷����ӵ��������� Orz",48,"��ʾ")(window.close);
        %end;
        %goto exit;
    %end;

    /*----------------------------------------------��ʼ��----------------------------------------------*/
    /*ͳһ������Сд*/
    %let indata               = %sysfunc(strip(%bquote(&indata)));
    %let table_def            = %sysfunc(strip(%bquote(&table_def)));
    %let stat_note            = %sysfunc(strip(%bquote(&stat_note)));
    %let outdata              = %sysfunc(strip(%bquote(&outdata)));
    %let weight               = %upcase(%sysfunc(strip(%bquote(&weight))));
    %let kappa_type           = %upcase(%sysfunc(strip(%bquote(&kappa_type))));
    %let kappa_weight         = %upcase(%sysfunc(strip(%bquote(&kappa_weight))));
    %let exact                = %upcase(%sysfunc(strip(%bquote(&exact))));
    %let null_kappa           = %upcase(%sysfunc(strip(%bquote(&null_kappa))));
    %let format               = %upcase(%sysfunc(strip(%bquote(&format))));
    %let del_temp_data        = %upcase(%sysfunc(strip(%bquote(&del_temp_data))));

    /*�����ֲ�����*/
    %local i j;

    /*----------------------------------------------�������----------------------------------------------*/
    /*INDATA*/
    %if %superq(indata) = %bquote() %then %do;
        %put ERROR: δָ���������ݼ���;
        %goto exit;
    %end;
    %else %do;
        %let reg_indata_id = %sysfunc(prxparse(%bquote(/^(?:([A-Za-z_][A-Za-z_\d]*)\.)?([A-Za-z_][A-Za-z_\d]*)(?:\((.*)\))?$/)));
        %if %sysfunc(prxmatch(&reg_indata_id, %bquote(&indata))) = 0 %then %do;
            %put ERROR: ���� INDATA = %bquote(&indata) ��ʽ����ȷ��;
            %goto exit;
        %end;
        %else %do;
            %let libname_in = %upcase(%sysfunc(prxposn(&reg_indata_id, 1, %superq(indata))));
            %let memname_in = %upcase(%sysfunc(prxposn(&reg_indata_id, 2, %superq(indata))));
            %let dataset_options_in = %sysfunc(prxposn(&reg_indata_id, 3, %superq(indata)));
            %if &libname_in = %bquote() %then %let libname_in = WORK; /*δָ���߼��⣬Ĭ��ΪWORKĿ¼*/
            proc sql noprint;
                select * from DICTIONARY.MEMBERS where libname = "&libname_in";
            quit;
            %if &SQLOBS = 0 %then %do;
                %put ERROR: &libname_in �߼��ⲻ���ڣ�;
                %goto exit;
            %end;
            proc sql noprint;
                select * from DICTIONARY.MEMBERS where libname = "&libname_in" and memname = "&memname_in";
            quit;
            %if &SQLOBS = 0 %then %do;
                %put ERROR: �� &libname_in �߼�����û���ҵ� &memname_in ���ݼ���;
                %goto exit;
            %end;
        %end;
    %end;
    %put NOTE: �������ݼ���ָ��Ϊ &libname_in..&memname_in;


    /*TABLE_DEF*/
    %if %superq(table_def) = %bquote() %then %do;
        %put ERROR: ���� TABLE_DEF Ϊ�գ�;
        %goto exit;
    %end;
    %else %do;
        %let reg_table_def_expr = %bquote(/^([A-Za-z_][A-Za-z_\d]*)(?:\(\s*(".*"(?:[\s,]+".*")*)?\s*\))?\s*\*\s*([A-Za-z_][A-Za-z_\d]*)(?:\(\s*(".*"(?:[\s,]+".*")*)?\s*\))?$/);
        %let reg_table_def_id = %sysfunc(prxparse(&reg_table_def_expr));
        %if %sysfunc(prxmatch(&reg_table_def_id, %bquote(&table_def))) = 0 %then %do;
            %put ERROR: ���� TABLE_DEF ��ʽ����ȷ��;
            %goto exit;
        %end;
        %else %do;
            %let table_row_var = %upcase(%sysfunc(prxposn(&reg_table_def_id, 1, %bquote(&table_def))));
            %let table_row_level = %sysfunc(prxposn(&reg_table_def_id, 2, %bquote(&table_def)));
            %let table_col_var = %upcase(%sysfunc(prxposn(&reg_table_def_id, 3, %bquote(&table_def))));
            %let table_col_level = %sysfunc(prxposn(&reg_table_def_id, 4, %bquote(&table_def)));

            /*���б��������Լ��*/
            %let IS_TABLE_DEF_VAR_EXIST = TRUE;
            proc sql noprint;
                select type into :type from DICTIONARY.COLUMNS where libname = "&libname_in" and memname = "&memname_in" and upcase(name) = "&table_row_var";
            quit;
            %if &SQLOBS = 0 %then %do; /*���ݼ���û���ҵ��б���*/
                %put ERROR: �� &libname_in..&memname_in ��û���ҵ��б��� &table_row_var;
                %let IS_TABLE_DEF_VAR_EXIST = FALSE;
            %end;

            proc sql noprint;
                select type into :type from DICTIONARY.COLUMNS where libname = "&libname_in" and memname = "&memname_in" and upcase(name) = "&table_col_var";
            quit;
            %if &SQLOBS = 0 %then %do; /*���ݼ���û���ҵ��б���*/
                %put ERROR: �� &libname_in..&memname_in ��û���ҵ��б��� &table_col_var;
                %let IS_TABLE_DEF_VAR_EXIST = FALSE;
            %end;

            %if &IS_TABLE_DEF_VAR_EXIST = FALSE %then %do;
                %goto exit;
            %end;
        %end;
    %end;


    /*STAT_NOTE*/
    %if %superq(stat_note) = %bquote() %then %do;
        %put ERROR: ���� STAT_NOTE Ϊ�գ�;
        %goto exit;
    %end;


    /*OUTDATA*/
    %if %superq(outdata) = %bquote() %then %do;
        %put ERROR: ���� OUTDATA Ϊ�գ�;
        %goto exit;
    %end;
    %else %do;
        %if %bquote(%upcase(&outdata)) = %bquote(#AUTO) %then %do;
            %let outdata = RES_&var_name;
        %end;
 
        %let reg_outdata_id = %sysfunc(prxparse(%bquote(/^(?:([A-Za-z_][A-Za-z_\d]*)\.)?([A-Za-z_][A-Za-z_\d]*)(?:\((.*)\))?$/)));
        %if %sysfunc(prxmatch(&reg_outdata_id, %bquote(&outdata))) = 0 %then %do;
            %put ERROR: ���� OUTDATA = %bquote(&outdata) ��ʽ����ȷ��;
            %goto exit;
        %end;
        %else %do;
            %let libname_out = %upcase(%sysfunc(prxposn(&reg_outdata_id, 1, %superq(outdata))));
            %let memname_out = %upcase(%sysfunc(prxposn(&reg_outdata_id, 2, %superq(outdata))));
            %let dataset_options_out = %sysfunc(prxposn(&reg_outdata_id, 3, %superq(outdata)));
            %if &libname_out = %bquote() %then %let libname_out = WORK; /*δָ���߼��⣬Ĭ��ΪWORKĿ¼*/
            proc sql noprint;
                select * from DICTIONARY.MEMBERS where libname = "&libname_out";
            quit;
            %if &SQLOBS = 0 %then %do;
                %put ERROR: &libname_out �߼��ⲻ���ڣ�;
                %goto exit;
            %end;
        %end;
        %put NOTE: ������ݼ���ָ��Ϊ &libname_out..&memname_out;
    %end;

    
    /*WEIGHT*/
    %if %superq(weight) ^= #NULL %then %do;
        %let reg_weight_id = %sysfunc(prxparse(%bquote(/^[A-Za-z_][A-Za-z_\d]*$/)));
        %if %sysfunc(prxmatch(&reg_weight_id, %bquote(&weight))) = 0 %then %do;
            %put ERROR: ���� WEIGHT = %bquote(&weight) ��ʽ����ȷ��;
            %goto exit;
        %end;
        %else %do;
            proc sql noprint;
                select type into :type from DICTIONARY.COLUMNS where libname = "&libname_in" and memname = "&memname_in" and upcase(name) = "&weight";
            quit;
            %if &SQLOBS = 0 %then %do; /*���ݼ���û���ҵ�����*/
                %put ERROR: �� &libname_in..&memname_in ��û���ҵ�Ȩ�ر��� &weight;
                %goto exit;
            %end;
            %else %do;
                %if %bquote(&type) ^= num %then %do;
                    %put ERROR: ���� WEIGHT ָ����Ȩ�ر��� %bquote(&weight) ������ֵ�͵ģ�;
                    %goto exit;
                %end;
            %end;
        %end;
    %end;


    /*KAPPA_TYPE*/
    %if %superq(kappa_type) = %bquote() %then %do;
        %put ERROR: ���� KAPPA_TYPE Ϊ�գ�;
        %goto exit;
    %end;

    %if %superq(kappa_type) = #SIMPLE %then %do;
        %put NOTE: ������� Kappa ϵ����;
    %end;
    %else %if %superq(kappa_type) = #WEIGHTED %then %do;
        %put NOTE: �������Ȩ Kappa ϵ����;
    %end;
    %else %do;
        %put ERROR: ���� KAPPA_TYPE ������ #SIMPLE �� #WEIGHTED ��;
        %goto exit;
    %end;


    /*KAPPA_WEIGHT*/
    %if %superq(kappa_type) = #SIMPLE %then %do;
        %if %superq(kappa_weight) ^= %bquote() and %superq(kappa_weight) ^= #AUTO %then %do;
            %put WARNING: δ�����Ȩ Kappa ϵ�������� KAPPA_WEIGHT �ѱ����ԣ�;
        %end;
    %end;
    %else %if %superq(kappa_type) = #WEIGHTED %then %do;
        %if %superq(kappa_weight) = #AUTO %then %do;
            %put NOTE: δָ��Ȩ�����ͣ�Ĭ��ʹ�� Cicchetti-Allison Ȩ�ؽ��м��㣡;
            %let kappa_weight = CA;
        %end;
        %else %if %superq(kappa_weight) = CA or %superq(kappa_weight) = %bquote(CICCHETTI-ALLISON) %then %do;
            %let kappa_weight = CA;
        %end;
        %else %if %superq(kappa_weight) = FC or %superq(kappa_weight) = %bquote(FLEISS-COHEN) %then %do;
            %let kappa_weight = FC;
        %end;
        %else %do;
            %put ERROR: ���� KAPPA_WEIGHT ָ����Ȩ������ %bquote(&KAPPA_WEIGHT) �����ڻ���֧�֣���֧�ֵ�Ȩ���������£�;
            %put ERROR- %bquote(CA, CICCHETTI-ALLISON);
            %put ERROR- %bquote(FC, FLEISS-COHEN);
            %goto exit;
        %end;
    %end;


    /*EXACT*/
    %if %superq(exact) = %bquote() %then %do;
        %put ERROR: ���� EXACT Ϊ�գ�;
        %goto exit;
    %end;

    %if %superq(exact) ^= TRUE and %superq(exact) ^= FALSE %then %do;
        %put ERROR: ���� EXACT ������ TRUE �� FALSE��;
        %goto exit;
    %end;


    /*NULL_KAPPA*/
    %if %superq(null_kappa) = %bquote() %then %do;
        %put ERROR: ���� NULL_KAPPA Ϊ�գ�;
        %goto exit;
    %end;

    %if %bquote(&exact) = TRUE %then %do;
        %if %superq(null_kappa) ^= #AUTO %then %do;
            %put WARNING: ��ȷ���鲻֧��ָ��������µ� Kappa ֵ������ NULL_KAPPA �ѱ����ԣ�;
            %let null_kappa = #AUTO;
        %end;
    %end;
    %else %do;
        %if %superq(null_kappa) = #AUTO %then %do;
            %let null_kappa = 0;
        %end;
        %else %do;
            %let reg_null_kappa_id = %sysfunc(prxparse(%bquote(/^-?\d+(?:\.\d*)?$/)));
            %if %sysfunc(prxmatch(&reg_null_kappa_id, %superq(null_kappa))) = 0 %then %do;
                %put ERROR: ���� NULL_KAPPA ��ʽ����ȷ��;
                %goto exit;
            %end;
            %else %do;
                %if %sysevalf(&null_kappa) < -1 or %sysevalf(&null_kappa) > 1 %then %do;
                    %put ERROR: ������µ� Kappa ֵ������ -1 �� 1 ֮�䣡;
                    %goto exit;
                %end;
            %end;
        %end;
    %end;
    


    /*SIDES*/
    %if %superq(sides) = %bquote() %then %do;
        %put ERROR: ���� SIDES Ϊ�գ�;
        %goto exit;
    %end;

    %if %superq(sides) ^= 1 and %superq(sides) ^= 2 %then %do;
        %put ERROR: ���� SIDES ������ 1��������飩 �� 2��˫����飩��;
        %goto exit;
    %end;


    /*FORMAT*/
    %if %bquote(&format) = %bquote() %then %do;
        %put ERROR: ��ͼָ������ FORMAT Ϊ�գ�;
        %goto exit;
    %end;

    %let reg_format = %bquote(/^((\$?[A-Za-z_]+(?:\d+[A-Za-z_]+)?)(?:\.|\d+\.\d*)|\$\d+\.|\d+\.\d*)$/);
    %let reg_format_id = %sysfunc(prxparse(&reg_format));
    %if %sysfunc(prxmatch(&reg_format_id, &format)) = 0 %then %do;
        %put ERROR: ���� FORMAT ��ʽ����ȷ��;
        %goto exit;
    %end;
    %else %do;
        %let format_base = %sysfunc(prxposn(&reg_format_id, 2, &format));
        %if %bquote(&format_base) ^= %bquote() %then %do;
            proc sql noprint;
                select * from DICTIONARY.FORMATS where fmtname = "&format_base" and fmttype = "F";
            quit;
            %if &SQLOBS = 0 %then %do;
                %put ERROR: �����ʽ &format �����ڣ�;
                %goto exit;
            %end;
        %end;
    %end;


    /*DEL_TEMP_DATA*/
    %if %superq(del_temp_data) ^= TRUE and %superq(del_temp_data) ^= FALSE %then %do;
        %put ERROR: ���� DEL_TEMP_DATA ������ TRUE �� FALSE��;
        %goto exit;
    %end;

    /*----------------------------------------------������----------------------------------------------*/
    /*1. ���Ʒ�������*/
    proc sql noprint;
        create table temp_indata as
            select * from &libname_in..&memname_in(%superq(dataset_options_in));
    quit;


    /*2. ����з���*/
    %if %superq(table_row_level) = %bquote() %then %do;
        proc sql noprint;
            create table temp_distinct_row_var as
                select
                    distinct &table_row_var
                from &libname_in..&memname_in(%superq(dataset_options_in)) order by &table_row_var;
            select &table_row_var into :table_row_level_1 - from temp_distinct_row_var;
            %let table_row_level_n = &SQLOBS;
        quit;
    %end;
    %else %do;
        %let table_row_level_n = %sysfunc(kcountw(%superq(table_row_level), %bquote(, ), %bquote(q)));
        %let reg_table_row_level_unit_expr = %bquote([\s,]+"(.*)");

        %if &table_row_level_n = 1 %then %do;
            %let reg_table_row_level_expr = %bquote(/^"(.*)"$/);
        %end;
        %else %do;
            %let reg_table_row_level_expr = %bquote(/^"(.*)"%sysfunc(repeat(%bquote(&reg_table_row_level_unit_expr), %eval(&table_row_level_n - 2)))$/);
        %end;
        %let reg_table_row_level_id = %sysfunc(prxparse(&reg_table_row_level_expr));

        %if %sysfunc(prxmatch(&reg_table_row_level_id, %superq(table_row_level))) = 0 %then %do;
            %put ERROR: �Ѽ�⵽�б��� &table_row_var �� &table_row_level_n �����࣬���ڽ�һ����ָ�����ʱ����������֮��Ĵ���;
            %goto exit;
        %end;
        %else %do;
            %do i = 1 %to &table_row_level_n;
                %let table_row_level_&i = %sysfunc(prxposn(&reg_table_row_level_id, &i, %superq(table_row_level)));
            %end;
        %end;
    %end;


    /*3. ����з���*/
    %if %superq(table_col_level) = %bquote() %then %do;
        proc sql noprint;
            create table temp_distinct_col_var as
                select
                    distinct &table_col_var
                from &libname_in..&memname_in(%superq(dataset_options_in)) order by &table_col_var;
            select &table_col_var into :table_col_level_1 - from temp_distinct_col_var;
            %let table_col_level_n = &SQLOBS;
        quit;
    %end;
    %else %do;
        %let table_col_level_n = %sysfunc(kcountw(%superq(table_col_level), %bquote(, ), %bquote(q)));
        %let reg_table_col_level_unit_expr = %bquote([\s,]+"(.*)");

        %if &table_col_level_n = 1 %then %do;
            %let reg_table_col_level_expr = %bquote(/^"(.*)"$/);
        %end;
        %else %do;
            %let reg_table_col_level_expr = %bquote(/^"(.*)"%sysfunc(repeat(%bquote(&reg_table_col_level_unit_expr), %eval(&table_col_level_n - 2)))$/);
        %end;
        %let reg_table_col_level_id = %sysfunc(prxparse(&reg_table_col_level_expr));

        %if %sysfunc(prxmatch(&reg_table_col_level_id, %superq(table_col_level))) = 0 %then %do;
            %put ERROR: �Ѽ�⵽�б��� &table_col_var �� &table_col_level_n �����࣬���ڽ�һ����ָ�����ʱ����������֮��Ĵ���;
            %goto exit;
        %end;
        %else %do;
            %do i = 1 %to &table_col_level_n;
                %let table_col_level_&i = %sysfunc(prxposn(&reg_table_col_level_id, &i, %superq(table_col_level)));
            %end;
        %end;
    %end;


    /*4. �С��з���ȡ������ʹR*C��ͳһ�ɷ���*/
    proc sql noprint;
        create table temp_distinct_var (var char(200), len num);
        %do i = 1 %to &table_row_level_n;
            select var from temp_distinct_var where var = "&&table_row_level_&i";
            %if &SQLOBS = 0 %then %do;
                insert into temp_distinct_var values("&&table_row_level_&i", %length(&&table_row_level_&i));
            %end;
        %end;
        %do i = 1 %to &table_col_level_n;
            select var from temp_distinct_var where var = "&&table_col_level_&i";
            %if &SQLOBS = 0 %then %do;
                insert into temp_distinct_var values("&&table_col_level_&i", %length(&&table_col_level_&i));
            %end;
        %end;

        select var into :table_level_1 - from temp_distinct_var;
        %let table_level_n = &SQLOBS;
        select max(len) into :len_max from temp_distinct_var;
    quit;

    /*���з���ȡ������ķ����С���*/
    %if &table_level_n < 2 %then %do;
        %put ERROR: ����ָ����СΪ 2��2 �����ϵı��;
        %goto exit_with_tempdata_created;
    %end;



    /*5. �ж�R*C���Ƿ�Ϊ�ձ���Ϊ�ձ�����ǰ��������*/
    proc sql noprint;
        select count(*) into :freq_all from temp_indata where &table_row_var in (select var from temp_distinct_var) and
                                                              &table_col_var in (select var from temp_distinct_var);
        %if &freq_all = 0 %then %do;
            %put NOTE: ��Ϊ�գ�δ�� Kappa ֵ���м��飡;
            %let kappap = %superq(placeholder);
            %goto temp_out;
        %end;
    quit;


    /*6. ��ʾ����ͼ��*/
    %if &kappa_type = #SIMPLE %then %do;
        %put NOTE: ���������±��Լ� Kappa ϵ�����м���:;
    %end;
    %else %if &kappa_type = #WEIGHTED %then %do;
        %put NOTE: ���������±��Լ�Ȩ Kappa ϵ�����м���, ע�⣺���з����˳��Ӱ���Ȩ Kappa ϵ���ļ�����������Ӱ��Լ�Ȩ Kappa ϵ�����м���� P ֵ����ȷ�ϱ�������з����˳��׼ȷ����;
    %end;

    %let note_table_line_0 = %bquote(%sysfunc(repeat(%bquote( ), %eval(&len_max - 1))));
    %do i = 1 %to &table_level_n;
        %if %bquote(&&table_level_&i) = %bquote() %then %do;
            %let note_table_line_0 = %superq(note_table_line_0)%bquote(|)%bquote( );
        %end;
        %else %do;
            %let note_table_line_0 = %superq(note_table_line_0)%bquote(|)%bquote(&&table_level_&i);
        %end;
    %end;
    %let note_table_line_0 = %superq(note_table_line_0)%bquote(|);
    %put NOTE: %superq(note_table_line_0);

    %do i = 1 %to &table_level_n;
        %let note_table_line_&i = %bquote(%sysfunc(putc(%bquote(&&table_level_&i), $&len_max..)));
        %do j = 1 %to &table_level_n;
            %let note_table_line_&i = %superq(note_table_line_&i)%bquote(|)%bquote(%sysfunc(repeat(%bquote(_), %sysfunc(max(%eval(%length(%bquote(&&table_level_&j)) - 1), 0)))));
        %end;
        %let note_table_line_&i = %superq(note_table_line_&i)%bquote(|);
        %put NOTE- %superq(note_table_line_&i);
    %end;

    /*2*2��ļ�ȨKappaϵ�����Kappaϵ�����������һ�£�����������Ϣ*/
    %if &kappa_type = #WEIGHTED %then %do;
        %if &table_row_level_n = 2 and &table_col_level_n = 2 %then %do;
            %put WARNING: ��Ȩ Kappa ϵ������ 2��2 ��ļ����������� Kappa ϵ��һ�£�;
            %let kappa_type = #SIMPLE;
        %end;
    %end;


    /*7. ���б���������࣬���Ƶ������*/
    proc sql noprint;
        /*�ҵ�δ��ʹ�õı����� FREQ&i*/
        %let IS_TEMP_FREQ_VAR_EXIST = TRUE;
        %let i = 1;
        %do %until(&IS_TEMP_FREQ_VAR_EXIST = FALSE);
            select * from DICTIONARY.COLUMNS where libname = "WORK" and memname = "TEMP_INDATA" and upcase(name) = "FREQ&i";
            %if &SQLOBS = 0 %then %do;
                %let IS_TEMP_FREQ_VAR_EXIST = FALSE;
            %end;
            %else %do;
                %let i = %eval(&i + 1);
            %end;
        %end;
        %let temp_freq_var = FREQ&i;

        /*�ҵ�δ��ʹ�õı����� ROWN&i*/
        %let IS_TEMP_ROWN_VAR_EXIST = TRUE;
        %let i = 1;
        %do %until(&IS_TEMP_ROWN_VAR_EXIST = FALSE);
            select * from DICTIONARY.COLUMNS where libname = "WORK" and memname = "TEMP_INDATA" and upcase(name) = "ROWN&i";
            %if &SQLOBS = 0 %then %do;
                %let IS_TEMP_ROWN_VAR_EXIST = FALSE;
            %end;
            %else %do;
                %let i = %eval(&i + 1);
            %end;
        %end;
        %let temp_rown_var = ROWN&i;

        /*�ҵ�δ��ʹ�õı����� COLN&i*/
        %let IS_TEMP_COLN_VAR_EXIST = TRUE;
        %let i = 1;
        %do %until(&IS_TEMP_COLN_VAR_EXIST = FALSE);
            select * from DICTIONARY.COLUMNS where libname = "WORK" and memname = "TEMP_INDATA" and upcase(name) = "COLN&i";
            %if &SQLOBS = 0 %then %do;
                %let IS_TEMP_COLN_VAR_EXIST = FALSE;
            %end;
            %else %do;
                %let i = %eval(&i + 1);
            %end;
        %end;
        %let temp_coln_var = COLN&i;

        /*���������Ȩ��Ϊ0�Ĺ۲�*/
        create table temp_indata_add_level_freq as
            select
                &table_row_var,
                &table_col_var,
                %if &weight = #NULL %then %do;
                    1
                %end;
                %else %do;
                    &weight
                %end; as &temp_freq_var,
                (case %do i = 1 %to &table_level_n;
                          when &table_row_var = "&&table_level_&i" then &i
                      %end;
                end) as &temp_rown_var,
                (case %do i = 1 %to &table_level_n;
                          when &table_col_var = "&&table_level_&i" then &i
                      %end;
                end) as &temp_coln_var
            from temp_indata
            outer union corr
            select
                 var as &table_row_var,
                 var as &table_col_var,
                 0   as &temp_freq_var,
                 monotonic() as &temp_rown_var,
                 monotonic() as &temp_coln_var
             from temp_distinct_var
            ;
    quit;
    

    /*8. ���� Kappa ϵ���������� P ֵ*/
    proc freq data = temp_indata_add_level_freq noprint;
        tables &temp_rown_var*&temp_coln_var /%if &kappa_type = #SIMPLE %then %do;
                                                  %if &exact = FALSE %then %do;
                                                      agree(nullkappa = &null_kappa)
                                                  %end;
                                                  %else %do;
                                                      agree
                                                  %end;
                                              %end;
                                              %else %do;
                                                  %if &exact = FALSE %then %do;
                                                      agree(wt = &kappa_weight nullwtkappa = &null_kappa)
                                                  %end;
                                                  %else %do;
                                                      agree(wt = &kappa_weight)
                                                  %end;
                                              %end;
                                              norow nocol nopercent;
        %if &exact = TRUE %then %do;
            exact
        %end;
        %else %do;
            test
        %end;
        %if &kappa_type = #WEIGHTED %then %do;
            wtkappa
        %end;
        %else %do;
            kappa
        %end;
        ;
        weight &temp_freq_var /zeros;
        output out = temp_out_kappa agree;
    run;


    /*9. ��ȡ Kappa ϵ���������� P ֵ*/
    proc sql noprint;
        /*��ȡ Kappa ϵ��*/
        %if &kappa_type = #SIMPLE %then %do;
            select _KAPPA_ format = &format into :KAPPA from temp_out_kappa;
        %end;
        %else %do;
            select _WTKAP_ format = &format into :KAPPA from temp_out_kappa;
        %end;

        %if &KAPPA = %bquote(.) %then %do;
            %put NOTE: �����ϡ�裬δ�� Kappa ϵ�����м��飡;
            %let kappap = %superq(placeholder);
        %end;
        %else %do;
            /*�ڲ��� SIDES = 1 ������£��Ƚ����� Kappa ϵ���������� Kappa ϵ�����������������Ҳ����*/
            %if &sides = 1 %then %do;
                %if %sysevalf(&KAPPA <= &null_kappa) %then %do;
                    %let test_side = L;
                %end;
                %else %do;
                    %let test_side = R;
                %end;
            %end;
            /*�ڲ��� SIDES = 2 ������£�����˫�����*/
            %else %do;
                %let test_side = 2;
            %end;

            /*�Լ� or ��Ȩ Kappa ϵ�����м���*/
            %if &kappa_type = #SIMPLE %then %do;
                %let kappa_method = KAPPA;
            %end;
            %else %do;
                %let kappa_method = WTKAP;
            %end;

            /*�Ƿ���о�ȷ����*/
            %if &exact = FALSE %then %do;
                %let test_type = %bquote();
            %end;
            %else %do;
                %let test_type = X;
            %end;

            /*Kappa P ֵ�ı�����*/
            %let kappap_var = %substr(&test_type.P&test_side._&kappa_method, 1, 8);
            
            select &kappap_var format = &format into :KAPPAP from temp_out_kappa;
        %end;
    quit;


    /*10. ����������ݼ�*/
    %temp_out:
    proc sql noprint;
        create table temp_out (item char(200), value char(200));
        insert into temp_out values("&stat_note", "&kappap");
    quit;
    

    /*11. ������ݼ�*/
    data &libname_out..&memname_out(%if %superq(dataset_options_out) = %bquote() %then %do;
                                        keep = item value
                                    %end;
                                    %else %do;
                                        &dataset_options_out
                                    %end;);
        set temp_out;
    run;

    /*----------------------------------------------���к���----------------------------------------------*/
    /*ɾ���м����ݼ�*/
    %exit_with_tempdata_created:
    %if %superq(del_temp_data) = TRUE %then %do;
        proc datasets noprint nowarn;
            delete temp_indata
                   temp_indata_add_level_freq
                   temp_distinct_row_var
                   temp_distinct_col_var
                   temp_distinct_var
                   temp_out_kappa
                   temp_out
                   ;
        quit;
    %end;

    %exit:
    %put NOTE: �� KappaP �ѽ������У�;
%mend;



