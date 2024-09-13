/*
===================================
Macro Name: KappaCI
Macro Label: Kappaֵ������������
Author: wtwang
Version Date: 2023-01-10 V1.0
              2023-12-06 V1.1
              2024-05-11 V1.1.1
===================================
*/

%macro KappaCI(INDATA,
               TABLE_DEF,
               OUTDATA,
               STAT_NOTE     = "Kappaϵ��",
               WEIGHT        = #NULL,
               KAPPA_TYPE    = #SIMPLE,
               KAPPA_WEIGHT  = #AUTO,
               ALPHA         = 0.05,
               FORMAT        = 6.3,
               PLACEHOLDER   = %str(-),
               DEL_TEMP_DATA = TRUE)
               /des = "Kappa ϵ��������������" parmbuff;

    /*�򿪰����ĵ�*/
    %if %qupcase(%superq(SYSPBUFF)) = %bquote((HELP)) or %qupcase(%superq(SYSPBUFF)) = %bquote(()) %then %do;
        X explorer "https://github.com/Snoopy1866/FreqStatKit/blob/main/docs/KappaCI/readme.md";
        %goto exit;
    %end;

    /*----------------------------------------------��ʼ��----------------------------------------------*/
    /*ͳһ������Сд*/
    %let indata               = %sysfunc(strip(%superq(indata)));
    %let table_def            = %sysfunc(strip(%superq(table_def)));
    %let stat_note            = %sysfunc(strip(%superq(stat_note)));
    %let outdata              = %sysfunc(strip(%superq(outdata)));
    %let weight               = %upcase(%sysfunc(strip(%superq(weight))));
    %let kappa_type           = %upcase(%sysfunc(strip(%superq(kappa_type))));
    %let kappa_weight         = %upcase(%sysfunc(strip(%superq(kappa_weight))));;
    %let alpha                = %upcase(%sysfunc(strip(%superq(alpha))));
    %let format               = %upcase(%sysfunc(strip(%superq(format))));
    %let del_temp_data        = %upcase(%sysfunc(strip(%superq(del_temp_data))));

    /*ͳ������Ӧ�������ʽ*/
    %let GLOBAL_format = 6.3;
    %let KAPPA_format  = &GLOBAL_format;
    %let CLM_format    = &GLOBAL_format;
    %let LCLM_format   = &CLM_format;
    %let UCLM_format   = &CLM_format;

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
        %if %sysfunc(prxmatch(&reg_indata_id, %superq(indata))) = 0 %then %do;
            %put ERROR: ���� INDATA = %superq(indata) ��ʽ����ȷ��;
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
        %if %sysfunc(prxmatch(&reg_table_def_id, %superq(table_def))) = 0 %then %do;
            %put ERROR: ���� TABLE_DEF = %superq(table_def) ��ʽ����ȷ��;
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

    %let reg_stat_note_id = %sysfunc(prxparse(%bquote(/^(\x22[^\x22]*\x22|\x27[^\x27]*\x27)$/)));
    %if %sysfunc(prxmatch(&reg_stat_note_id, %superq(stat_note))) %then %do;
        %let stat_note_quote = %superq(stat_note);
    %end;
    %else %do;
        %put ERROR: ���� STAT_NOTE ��ʽ����ȷ��ָ�����ַ�������ʹ��ƥ������Ű�Χ��;
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
        %if %sysfunc(prxmatch(&reg_outdata_id, %superq(outdata))) = 0 %then %do;
            %put ERROR: ���� OUTDATA = %superq(outdata) ��ʽ����ȷ��;
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
        %if %sysfunc(prxmatch(&reg_weight_id, %superq(weight))) = 0 %then %do;
            %put ERROR: ���� WEIGHT = %superq(weight) ��ʽ����ȷ��;
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


    /*ALPHA*/
    %if %superq(alpha) = %bquote() %then %do;
        %put ERROR: ���� ALPHA Ϊ�գ�;
        %goto exit;
    %end;

    %let reg_alpha_id = %sysfunc(prxparse(%bquote(/^0?\.\d+$/)));
    %if %sysfunc(prxmatch(&reg_alpha_id, %bquote(&alpha))) = 0 %then %do;
        %put ERROR: ���� ALPHA ��ʽ����ȷ��;
        %goto exit;
    %end;
    %else %do;
        %if %sysevalf(%bquote(&alpha) <= 0) or %sysevalf(%bquote(&alpha) >= 1) %then %do;
            %put ERROR: ���� ALPHA ������0��1֮���һ����ֵ��;
            %goto exit;
        %end;
    %end;


    /*FORMAT*/
    %macro temp_format_update(format_2be_update, format_new); /*����ͳ���������ʽ���ڲ������*/
        %if &format_2be_update = GLOBAL %then %do;
            %let KAPPA_format = &format_new;
            %let LCLM_format = &format_new;
            %let UCLM_format = &format_new;
        %end;
        %else %if &format_2be_update = KAPPA %then %do;
            %let KAPPA_format = &format_new;
        %end;
        %else %if &format_2be_update = CLM %then %do;
            %let LCLM_format = &format_new;
            %let UCLM_format = &format_new;
        %end;
        %else %if &format_2be_update = LCLM %then %do;
            %let LCLM_format = &format_new;
        %end;
        %else %if &format_2be_update = UCLM %then %do;
            %let UCLM_format = &format_new;
        %end;
    %mend;

    %if %superq(format) = %bquote() %then %do;
        %put ERROR: ���� FORMAT Ϊ�գ�;
        %goto exit;
    %end;

    %let reg_format_unit = %bquote(/(?:#(KAPPA|LCLM|UCLM|CLM)\s*=\s*)?((\$?[A-Za-z_]+(?:\d+[A-Za-z_]+)?)(?:\.|\d+\.\d*)|\$\d+\.|\d+\.\d*)/);
    %let reg_format_unit_id = %sysfunc(prxparse(&reg_format_unit));
    %let start = 1;
    %let stop = %length(%bquote(&format));
    %let position = 1;
    %let length = 1;
    %let i = 1;
    %syscall prxnext(reg_format_unit_id, start, stop, format, position, length);
    %do %while(&position > 0);
        %let format_part_&i = %substr(%bquote(&format), &position, &length);
        %if %sysfunc(prxmatch(&reg_format_unit_id, %bquote(&&format_part_&i))) %then %do;
            %let format_index_&i = %sysfunc(prxposn(&reg_format_unit_id, 1, %bquote(&&format_part_&i))); /*��i���޸ĸ�ʽ��ָ������*/
            %let format_&i = %sysfunc(prxposn(&reg_format_unit_id, 2, %bquote(&&format_part_&i))); /*��i����ʽ����*/
            %let fomrat_&i._base = %sysfunc(prxposn(&reg_format_unit_id, 3, %bquote(&&format_part_&i))); /*��i����ʽ���Ƶ�base����*/

            %if %bquote(&&format_index_&i) = %bquote() %then %do; /*δָ���޸ĸ�ʽ��ͳ�������ƣ�Ĭ��ȫ���޸�*/
                %let format_index_&i = GLOBAL;
            %end;
            %if %bquote(&&fomrat_&i._base) = %bquote() %then %do; /*ָ���ļ򵥸�ʽ��ֱ���޸�*/
                %temp_format_update(&&format_index_&i, &&format_&i);
            %end;
            %else %do; /*ָ����������ʽ����Ҫ��һ���жϸ�ʽ�Ĵ�����*/
                proc sql noprint;
                    select * from DICTIONARY.FORMATS where fmtname = "&&fomrat_&i._base" and fmttype = "F";
                quit;
                %if &SQLOBS = 0 %then %do;
                    %put ERROR: Ϊͳ���� &&format_index_&i ָ���������ʽ &&format_&i �����ڣ�;
                    %goto exit;
                %end;
                %else %do;
                    %temp_format_update(&&format_index_&i, &&format_&i);
                %end;
            %end;
            %syscall prxnext(reg_format_unit_id, start, stop, format, position, length);
            %let i = %eval(&i + 1);
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
            %put NOTE: ��Ϊ�գ�δ���� Kappa ֵ��;
            %let kappa_and_ci = %superq(placeholder);
            %goto temp_out;
        %end;
    quit;


    /*6. ��ʾ����ͼ��*/
    %if &kappa_type = #SIMPLE %then %do;
        %put NOTE: ���������±������ Kappa ϵ��:;
    %end;
    %else %if &kappa_type = #WEIGHTED %then %do;
        %put NOTE: ���������±������Ȩ Kappa ϵ��, ע�⣺���з����˳��Ӱ���Ȩ Kappa ϵ�������ռ���������ȷ�ϱ�������з����˳��׼ȷ����;
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

    /*2*2��ļ�ȨKappaϵ�����Kappaϵ�����һ�£�����������Ϣ*/
    %if &kappa_type = #WEIGHTED %then %do;
        %if &table_row_level_n = 2 and &table_col_level_n = 2 %then %do;
            %put WARNING: ��Ȩ Kappa ϵ������ 2��2 ��ļ�������� Kappa ϵ��һ�£�;
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
    

    /*8. ���� Kappa ֵ������������*/
    proc freq data = temp_indata_add_level_freq noprint;
        tables &temp_rown_var*&temp_coln_var /%if &kappa_type = #WEIGHTED %then %do;
                                                  agree(wt = &kappa_weight)
                                              %end;
                                              %else %do;
                                                  agree
                                              %end; alpha = &alpha norow nocol nopercent;
        weight &temp_freq_var /zeros;
        output out = temp_out_kappa agree;
    run;


    /*9. ��ȡ Kappa ֵ������������*/
    proc sql noprint;
        select * from DICTIONARY.TABLES where libname = "WORK" and memname = "TEMP_OUT_KAPPA";
        %if &SQLOBS = 0 %then %do;
            %let kappa_and_ci = %superq(placeholder);
        %end;
        %else %do;
            %if &kappa_type = #WEIGHTED %then %do;
                select _WTKAP_ format = &KAPPA_format into :KAPPA from temp_out_kappa;
                select L_WTKAP format = &LCLM_format  into :LCLM  from temp_out_kappa;
                select U_WTKAP format = &UCLM_format  into :UCLM  from temp_out_kappa;
            %end;
            %else %do;
                select _KAPPA_ format = &KAPPA_format into :KAPPA from temp_out_kappa;
                select L_KAPPA format = &LCLM_format  into :LCLM  from temp_out_kappa;
                select U_KAPPA format = &UCLM_format  into :UCLM  from temp_out_kappa;
            %end;

            %if %sysevalf(&KAPPA = %bquote(.)) %then %do;
                %put NOTE: �����ϡ�裬δ���� Kappa ϵ����;
                %let kappa_and_ci = %superq(placeholder);
            %end;
            %else %do;
                %let kappa_and_ci = %bquote(%sysfunc(strip(&KAPPA))(%sysfunc(strip(&LCLM)), %sysfunc(strip(&UCLM))));
            %end;
        %end;
    quit;


    /*10. ����������ݼ�*/
    %temp_out:
    proc sql noprint;
        create table temp_out (item char(200), value char(200));
        insert into temp_out values(%unquote(&stat_note_quote), "&kappa_and_ci");
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

    /*ɾ����ʱ��*/
    proc catalog catalog = work.sasmacr;
        delete temp_format_update.macro;
    quit;

    %exit:
    %put NOTE: �� KappaCI �ѽ������У�;
%mend;
