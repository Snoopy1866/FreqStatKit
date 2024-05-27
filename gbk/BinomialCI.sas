/*
===================================
Macro Name: BinomialCI
Macro Label: �ʣ����ɱȣ�������������
Author: wtwang
Version Date: 2023-01-04 V1.0
              2024-05-11 V1.0.1
===================================
*/

%macro BinomialCI(INDATA,
                  COND_POS,
                  COND_NEG,
                  STAT_NOTE,
                  OUTDATA,
                  WEIGHT           = #NULL,
                  ADJUST_METHOD    = #NULL,
                  ADJUST_THRESHOLD = #AUTO,
                  ALPHA            = 0.05,
                  FORMAT           = PERCENTN9.2,
                  PLACEHOLDER      = "-",
                  DEL_TEMP_DATA    = TRUE)
                  /des = "�ʣ����ɱȣ�������������" parmbuff;

    /*�򿪰����ĵ�*/
    %if %qupcase(%superq(SYSPBUFF)) = %bquote((HELP)) or %qupcase(%superq(SYSPBUFF)) = %bquote(()) %then %do;
        X explorer "https://github.com/Snoopy1866/FreqStatKit/blob/main/docs/BinomialCI/readme.md";
        %goto exit;
    %end;

    /*----------------------------------------------��ʼ��----------------------------------------------*/
    /*ͳһ������Сд*/
    %let indata               = %sysfunc(strip(%superq(indata)));
    %let cond_pos             = %sysfunc(strip(%superq(cond_pos)));
    %let cond_neg             = %sysfunc(strip(%superq(cond_neg)));
    %let stat_note            = %sysfunc(strip(%superq(stat_note)));
    %let outdata              = %sysfunc(strip(%superq(outdata)));
    %let weight               = %upcase(%sysfunc(strip(%superq(weight))));
    %let adjust_method        = %upcase(%sysfunc(strip(%superq(adjust_method))));
    %let adjust_threshold     = %upcase(%sysfunc(compbl(%sysfunc(strip(%superq(adjust_threshold))))));
    %let alpha                = %upcase(%sysfunc(strip(%superq(alpha))));
    %let format               = %upcase(%sysfunc(strip(%superq(format))));
    %let del_temp_data        = %upcase(%sysfunc(strip(%superq(del_temp_data))));

    /*ͳ������Ӧ�������ʽ*/
    %let GLOBAL_format = percentn9.2;
    %let RATE_format   = &GLOBAL_format;
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
            %let libname_in = %upcase(%sysfunc(prxposn(&reg_indata_id, 1, &indata)));
            %let memname_in = %upcase(%sysfunc(prxposn(&reg_indata_id, 2, &indata)));
            %let dataset_options_in = %sysfunc(prxposn(&reg_indata_id, 3, &indata));
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


    %let IS_COND_SPECIFIED = TRUE;
    /*COND_POS*/
    %if %superq(cond_pos) = %bquote() %then %do;
        %put ERROR: ���� COND_POS Ϊ�գ�;
        %let IS_COND_SPECIFIED = FALSE;
    %end;


    /*COND_POS*/
    %if %superq(cond_neg) = %bquote() %then %do;
        %put ERROR: ���� COND_NEG Ϊ�գ�;
        %let IS_COND_SPECIFIED = FALSE;
    %end;

    %if &IS_COND_SPECIFIED = FALSE %then %do;
        %goto exit;
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
            %let libname_out = %upcase(%sysfunc(prxposn(&reg_outdata_id, 1, &outdata)));
            %let memname_out = %upcase(%sysfunc(prxposn(&reg_outdata_id, 2, &outdata)));
            %let dataset_options_out = %sysfunc(prxposn(&reg_outdata_id, 3, &outdata));
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


    /*ADJUST_METHOD*/
    %if %superq(adjust_method) = %bquote() %then %do;
        %put ERROR: ���� ADJUST_METHOD Ϊ�գ�;
        %goto exit;
    %end;

    %if %superq(adjust_method) = #NULL %then %do;
        %put NOTE: δָ��У��������Ĭ��ʹ�� WALD �������������䣡;
    %end;
    %else %do;
        %let reg_adjust_method_id = %sysfunc(prxparse(%bquote(/^(?:WILSON\(CORRECT\)|SCORE\(CORRECT\)|LIKELIHOODRATIO|CLOPPERPEARSON|AGRESTICOULL|JEFFREYS|SCOREC|WILSONC|BLAKER|WILSON|EXACT|LOGIT|SCORE|MIDP|LOG|AC|CP|LR|MP|J)$/)));
        %if %sysfunc(prxmatch(&reg_adjust_method_id, %superq(adjust_method))) = 0 %then %do;
            %put ERROR: ���� ADJUST_METHOD ָ����У������ %superq(ADJUST_METHOD) �����ڻ���֧�֣���֧�ֵ�У���������£�;
            %put ERROR- %bquote(AC, AGRESTICOULL);
            %put ERROR- %bquote(BLAKER);
            %put ERROR- %bquote(CP, CLOPPERPEARSON, EXACT);
            %put ERROR- %bquote(J, JEFFREYS);
            %put ERROR- %bquote(LOG, LOGIT);
            %put ERROR- %bquote(LR, LIKELIHOODRATIO);
            %put ERROR- %bquote(MP, MIDP);
            %put ERROR- %bquote(WILSON, SCORE);
            %put ERROR- %bquote(WILSONC, WILSON(CORRECT), SCOREC, SCORE(CORRECT));
            %goto exit;
        %end;
    %end;


    /*ADJUST_THRESHOLD*/
    %if %superq(adjust_method) = #NULL %then %do;
        %if %superq(adjust_threshold) ^= %bquote() and %superq(adjust_threshold) ^= #AUTO %then %do;
            %put WARNING: δָ��У������������ ADJUST_THRESHOLD �ѱ����ԣ�;
        %end;
    %end;
    %else %do;
        %if %superq(adjust_threshold) = #AUTO %then %do;
            %put NOTE: δָ��У��������Ĭ�ϵ����ɱȣ��ʣ����ڻ����0.9ʱ�������������У����;
            %let adjust_threshold = %bquote(#RATE >= 0.9);
            %let adjust_threshold_cond_expr = %nrstr(&RATE >= 0.9);
        %end;
        %else %do;
            %let reg_adjust_threshold_id = %sysfunc(prxparse(%bquote(/^\(*\s?#(RATE|LCLM|UCLM)\s?(NE|\^=|~=|GE|>=|LE|<=|GT|>|LT|<|EQ|=)\s?(\d+(?:\.\d+)?)\s?\)*(?:\s(AND|OR|&|\|)\s\(*\s?#(RATE|LCLM|UCLM)\s?(NE|\^=|~=|GE|>=|LE|<=|GT|>|LT|<|EQ|=)\s?(\d+(?:\.\d+)?)\s?\)*)*$/)));
            %if %sysfunc(prxmatch(&reg_adjust_threshold_id, %superq(adjust_threshold))) = 0 %then %do;
                %put ERROR: ���� ADJUST_THRESHOLD = %superq(adjust_threshold) ��ʽ����ȷ��;
                %goto exit;
            %end;
            %else %do;
                %if %sysfunc(count(%bquote(adjust_threshold), %bquote(%str(%()))) = %sysfunc(count(%bquote(adjust_threshold), %bquote(%str(%))))) %then %do;
                    %let adjust_threshold_cond_expr = %nrstr(%sysfunc(transtrn(%bquote(&adjust_threshold), %bquote(#), %nrbquote(&)))); /*У��������Ӧ�ĺ���ʽ*/
                %end;
                %else %do;
                    %put ERROR: ���� ADJUST_THRESHOLD = %bquote(&adjust_threshold) ���Ų�ƥ�䣡;
                    %goto exit;
                %end;
            %end;
        %end;
    %end;


    /*ALPHA*/
    %if %superq(alpha) = %bquote() %then %do;
        %put ERROR: ���� ALPHA Ϊ�գ�;
        %goto exit;
    %end;

    %let reg_alpha_id = %sysfunc(prxparse(%bquote(/^0?\.\d+$/)));
    %if %sysfunc(prxmatch(&reg_alpha_id, %superq(alpha))) = 0 %then %do;
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
            %let RATE_format = &format_new;
            %let LCLM_format = &format_new;
            %let UCLM_format = &format_new;
        %end;
        %else %if &format_2be_update = RATE %then %do;
            %let RATE_format = &format_new;
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

    %let reg_format_unit = %bquote(/(?:#(RATE|LCLM|UCLM|CLM)\s*=\s*)?((\$?[A-Za-z_]+(?:\d+[A-Za-z_]+)?)(?:\.|\d+\.\d*)|\$\d+\.|\d+\.\d*)/);
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
            select * from &libname_in..&memname_in(&dataset_options_in);
    quit;


    /*2. Ƶ������*/
    %if %bquote(&weight) = %bquote(#NULL) %then %do;
        proc sql noprint;
            select count(*) into: pos_n from temp_indata where &cond_pos; /*���ɹ���������*/
            select count(*) into: neg_n from temp_indata where &cond_neg; /*��ʧ�ܡ�������*/
        quit;
    %end;
    %else %do;
        proc sql noprint;
            select sum(&weight) into: pos_n from temp_indata where &cond_pos; /*���ɹ���������*/
            select sum(&weight) into: neg_n from temp_indata where &cond_neg; /*��ʧ�ܡ�������*/
        quit;
    %end;

    %if &SYSERR > 0 %then %do;
        %put ERROR: �ڳ��Լ���Ƶ��ʱ���ִ��󣬵��´����ԭ���ǲ��� COND_POS �� COND_NEG �﷨����;
        %goto exit_with_error_in_sqlcond;
    %end;

    /*���ɹ����͡�ʧ�ܡ���Ƶ����Ϊ0���޷�������������ʱ����ǰ��������*/
    %if &pos_n = 0 and &neg_n = 0 %then %do;
        %let rate = .;
        %let rate_fmt = %bquote(&placeholder);
        %let lclm = .;
        %let lclm_fmt = %bquote(&placeholder);
        %let uclm = .;
        %let uclm_fmt = %bquote(&placeholder);
        %let rate_and_ci = %bquote(&placeholder);
        %goto temp_out;
    %end;


    /*3. �������ɹ����͡�ʧ�ܡ�Ƶ�������ݼ�*/
    proc sql noprint;
        create table temp_freq (orres char(200), n num);
        insert into temp_freq
            values("positive", &pos_n)
            values("negative", &neg_n);
    quit;


    /*4. �����ʼ�����������*/
    proc freq data = temp_freq noprint;
        tables orres /binomial(level = "positive" wald %if %bquote(&adjust_method) ^= #NULL %then %do;
                                                           &adjust_method
                                                       %end;) alpha = &alpha missing;
        weight n /zeros;
        output out = temp_ci binomial;
    quit;

    /*5. �����Ƿ�ָ��У�������Լ�У����������ȡ�ʼ�����������*/
    proc sql noprint;
        select _BIN_ format = 16.14 into :RATE from temp_ci;
        select L_BIN format = 16.14 into :LCLM from temp_ci;
        select U_BIN format = 16.14 into :UCLM from temp_ci;
    quit;
    %if %bquote(&adjust_method) ^= #NULL %then %do; /*ָ����У������*/
        proc sql noprint;
            %if %sysevalf(%unquote(&adjust_threshold_cond_expr)) %then %do;
                %put NOTE: У������ %unquote(&adjust_threshold_cond_expr) ��������ʹ�� &adjust_method ���������������У����;
                /*У���������㣬��ȡУ�������������������*/
                select _BIN_ format = &RATE_format into :RATE_FMT from temp_ci;
                %if %bquote(&adjust_method) = CP or 
                    %bquote(&adjust_method) = CLOPPERPEARSON or 
                    %bquote(&adjust_method) = EXACT %then %do;
                    select XL_BIN format = &LCLM_format into :LCLM_FMT from temp_ci;
                    select XU_BIN format = &UCLM_format into :UCLM_FMT from temp_ci;
                %end;
                %else %if %bquote(&adjust_method) = WILSON or
                          %bquote(&adjust_method) = WILSONC or
                          %bquote(&adjust_method) = %bquote(WILSON(CORRECT)) or
                          %bquote(&adjust_method) = SCORE or
                          %bquote(&adjust_method) = SCOREC or
                          %bquote(&adjust_method) = %bquote(SCORE(CORRECT)) %then %do;
                    select L_W_BIN format = &LCLM_format into :LCLM_FMT from temp_ci;
                    select U_W_BIN format = &UCLM_format into :UCLM_FMT from temp_ci;
                %end;
                %else %if %bquote(&adjust_method) = AC or
                          %bquote(&adjust_method) = AGRESTICOULL %then %do;
                    select L_AC_BIN format = &LCLM_format into :LCLM_FMT from temp_ci;
                    select U_AC_BIN format = &UCLM_format into :UCLM_FMT from temp_ci;
                %end;
                %else %if %bquote(&adjust_method) = BLAKER %then %do;
                    select L_BK_BIN format = &LCLM_format into :LCLM_FMT from temp_ci;
                    select U_BK_BIN format = &UCLM_format into :UCLM_FMT from temp_ci;
                %end;
                %else %if %bquote(&adjust_method) = J or
                          %bquote(&adjust_method) = JEFFREYS %then %do;
                    select L_J_BIN format = &LCLM_format into :LCLM_FMT from temp_ci;
                    select U_J_BIN format = &UCLM_format into :UCLM_FMT from temp_ci;
                %end;
                %else %if %bquote(&adjust_method) = LOG or
                          %bquote(&adjust_method) = LOGIT %then %do;
                    select L_LG_BIN format = &LCLM_format into :LCLM_FMT from temp_ci;
                    select U_LG_BIN format = &UCLM_format into :UCLM_FMT from temp_ci;
                %end;
                %else %if %bquote(&adjust_method) = LR or
                          %bquote(&adjust_method) = LIKELIHOODRATIO %then %do;
                    select L_LR_BIN format = &LCLM_format into :LCLM_FMT from temp_ci;
                    select U_LR_BIN format = &UCLM_format into :UCLM_FMT from temp_ci;
                %end;
                %else %if %bquote(&adjust_method) = MP or
                          %bquote(&adjust_method) = MIDP %then %do;
                    select L_MP_BIN format = &LCLM_format into :LCLM_FMT from temp_ci;
                    select U_MP_BIN format = &LCLM_format into :UCLM_FMT from temp_ci;
                %end;
            %end;
            %else %do;
                /*У�����������㣬��ȡWALD���������������*/
                select _BIN_ format = &RATE_format into :RATE_FMT from temp_ci;
                select L_BIN format = &LCLM_format into :LCLM_FMT from temp_ci;
                select U_BIN format = &UCLM_format into :UCLM_FMT from temp_ci;
            %end;
        quit;
    %end;
    %else %do; /*δָ��У������*/
        proc sql noprint;
            select _BIN_ format = &RATE_format into :RATE_FMT from temp_ci;
            select L_BIN format = &LCLM_format into :LCLM_FMT from temp_ci;
            select U_BIN format = &UCLM_format into :UCLM_FMT from temp_ci;
        quit;
    %end;
    %let rate_and_ci = %bquote(%sysfunc(strip(&RATE_FMT))(%sysfunc(strip(&LCLM_FMT)), %sysfunc(strip(&UCLM_FMT))));


    /*6. ����������ݼ�*/
    %temp_out:
    proc sql noprint;
        create table temp_out (item char(200),
                               n num,
                               pos_n num,
                               neg_n num,
                               rate num,
                               rate_fmt char(200),
                               lclm num,
                               lclm_fmt char(200),
                               uclm num,
                               uclm_fmt char(200),
                               value char(200));
        insert into temp_out
            values(%unquote(&stat_note_quote), %eval(&pos_n + &neg_n), &pos_n, &neg_n, &rate, "&rate_fmt", &lclm, "&lclm_fmt", &uclm, "&uclm_fmt", "&rate_and_ci");
    quit;


    /*7. ������ݼ�*/
    data &libname_out..&memname_out(%if %bquote(&dataset_options_out) = %bquote() %then %do;
                                        keep = item value
                                    %end;
                                    %else %do;
                                        &dataset_options_out
                                    %end;);
        set temp_out;
    run;

    /*----------------------------------------------���к���----------------------------------------------*/
    %exit_with_error_in_sqlcond:
    /*ɾ���м����ݼ�*/
    %if %superq(del_temp_data) = TRUE %then %do;
        proc datasets noprint nowarn;
            delete temp_indata
                   temp_freq
                   temp_ci
                   temp_out
                   ;
        quit;
    %end;

    /*ɾ����ʱ��*/
    proc catalog catalog = work.sasmacr;
        delete temp_format_update.macro;
    quit;

    %exit:
    %put NOTE: �� BinomialCI �ѽ������У�;
%mend;
