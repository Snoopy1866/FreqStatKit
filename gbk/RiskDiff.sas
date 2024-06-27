/*
===================================
Macro Name: Riskdiff
Macro Label: �����ʲ����������
Author: wtwang
Version Date: 2024-05-10 V1.0
              2024-06-27 V1.1
===================================
*/

%macro RiskDiff(INDATA,
                GROUP,
                RESPONSE,
                STAT_NOTE,
                OUTDATA,
                WEIGHT        = #NULL,
                METHOD        = WALD,
                ALPHA         = 0.05,
                FORMAT        = PERCENTN9.2,
                DEL_TEMP_DATA = TRUE)
                /des = "�����ʲ����������" parmbuff;

    /*�򿪰����ĵ�*/
    %if %qupcase(%superq(SYSPBUFF)) = %bquote((HELP)) or %qupcase(%superq(SYSPBUFF)) = %bquote(()) %then %do;
        X explorer "https://github.com/Snoopy1866/FreqStatKit/blob/main/docs/RiskDiff/readme.md";
        %goto exit;
    %end;

    /*----------------------------------------------��ʼ��----------------------------------------------*/
    /*ͳһ������Сд*/
    %let indata               = %sysfunc(strip(%superq(indata)));
    %let group                = %sysfunc(strip(%superq(group)));
    %let response             = %sysfunc(strip(%superq(response)));
    %let stat_note            = %sysfunc(strip(%superq(stat_note)));
    %let outdata              = %sysfunc(strip(%superq(outdata)));
    %let weight               = %upcase(%sysfunc(strip(%superq(weight))));
    %let method               = %upcase(%sysfunc(compress(%superq(method))));
    %let alpha                = %sysfunc(strip(%superq(alpha)));
    %let format               = %upcase(%sysfunc(strip(%superq(format))));
    %let del_temp_data        = %upcase(%sysfunc(strip(%superq(del_temp_data))));

    /*�����ֲ�����*/
    %local i j;

    /*----------------------------------------------�������----------------------------------------------*/
    /*INDATA*/
    %if %superq(indata) = %bquote() %then %do;
        %put ERROR: δָ���������ݼ���;
        %goto exit;
    %end;

    %let reg_indata_id = %sysfunc(prxparse(%bquote(/^(?:([A-Za-z_][A-Za-z_\d]*)\.)?([A-Za-z_][A-Za-z_\d]*)(?:\((.*)\))?$/)));
    %if %sysfunc(prxmatch(&reg_indata_id, %superq(indata))) %then %do;
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
    %else %do;
        %put ERROR: ���� INDATA = %superq(indata) ��ʽ����ȷ��;
        %goto exit;
    %end;

    %put NOTE: �������ݼ���ָ��Ϊ &libname_in..&memname_in;


    /*GROUP*/
    %if %superq(group) = %bquote() %then %do;
        %put ERROR: ���� GROUP Ϊ�գ�;
        %goto exit;
    %end;

    %let reg_group_id = %sysfunc(prxparse(%bquote(/^([A-Za-z_][A-Za-z0-9_]*)\((?:(\x22[^\x22]+\x22|\x27[^\x27]+\x27)\s*-\s*(\x22[^\x22]+\x22|\x27[^\x27]+\x27))\)$/)));
    %if %sysfunc(prxmatch(&reg_group_id, %superq(group))) %then %do;
        %let group_var             = %upcase(%sysfunc(prxposn(&reg_group_id, 1, %superq(group)))); /*�����ʲ��������*/
        %let group_level_treatment = %sysfunc(prxposn(&reg_group_id, 2, %superq(group)));          /*�����ʲ�����ˮƽ-������*/
        %let group_level_control   = %sysfunc(prxposn(&reg_group_id, 3, %superq(group)));          /*�����ʲ�����ˮƽ-������*/

        proc sql noprint;
            select type into : type from DICTIONARY.COLUMNS where libname = "&libname_in" and memname = "&memname_in" and upcase(name) = "&group_var";
        quit;
        %if &SQLOBS = 0 %then %do;
            %put ERROR: ���� GROUP ָ���ı��� &group_var �����ڣ�;
            %goto exit;
        %end;
        %if &type ^= char %then %do;
            %put ERROR: ���� GROUP �������ַ��ͱ�����;
            %goto exit;
        %end;
    %end;
    %else %do;
        %put ERROR: ���� GROUP = %superq(group) ��ʽ����ȷ��;
        %goto exit;
    %end;


    /*RESPONSE*/
    %if %superq(response) = %bquote() %then %do;
        %put ERROR: ���� RESPONSE Ϊ�գ�;
        %goto exit;
    %end;

    %let reg_response_id = %sysfunc(prxparse(%bquote(/^([A-Za-z_][A-Za-z0-9_]*)\((?:(\x22[^\x22]+\x22|\x27[^\x27]+\x27))\)$/)));
    %if %sysfunc(prxmatch(&reg_response_id, %superq(response))) %then %do;
        %let response_var   = %upcase(%sysfunc(prxposn(&reg_response_id, 1, %superq(response)))); /*�����ʲ����Ӧ����*/
        %let response_level = %sysfunc(prxposn(&reg_response_id, 2, %superq(response)));          /*�����ʲ����Ӧˮƽ*/

        proc sql noprint;
            select type into : type from DICTIONARY.COLUMNS where libname = "&libname_in" and memname = "&memname_in" and upcase(name) = "&response_var";
        quit;
        %if &SQLOBS = 0 %then %do;
            %put ERROR: ���� RESPONSE ָ���ı��� &response_var �����ڣ�;
            %goto exit;
        %end;
        %if &type ^= char %then %do;
            %put ERROR: ���� RESPONSE �������ַ��ͱ�����;
            %goto exit;
        %end;
    %end;
    %else %do;
        %put ERROR: ���� RESPONSE = %superq(response) ��ʽ����ȷ��;
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

    %let reg_outdata_id = %sysfunc(prxparse(%bquote(/^(?:([A-Za-z_][A-Za-z_\d]*)\.)?([A-Za-z_][A-Za-z_\d]*)(?:\((.*)\))?$/)));
    %if %sysfunc(prxmatch(&reg_outdata_id, %superq(outdata))) %then %do;
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
    %else %do;
        %put ERROR: ���� OUTDATA = %superq(outdata) ��ʽ����ȷ��;
        %goto exit;
    %end;

    %put NOTE: ������ݼ���ָ��Ϊ &libname_out..&memname_out;


    /*WEIGHT*/
    %if %superq(weight) ^= #NULL %then %do;
        %let reg_weight_id = %sysfunc(prxparse(%bquote(/^[A-Za-z_][A-Za-z_\d]*$/)));
        %if %sysfunc(prxmatch(&reg_weight_id, %superq(weight))) %then %do;
            proc sql noprint;
                select type into :type from DICTIONARY.COLUMNS where libname = "&libname_in" and memname = "&memname_in" and upcase(name) = "&weight";
            quit;
            %if &SQLOBS = 0 %then %do; /*���ݼ���û���ҵ�����*/
                %put ERROR: �� &libname_in..&memname_in ��û���ҵ�Ȩ�ر��� &weight;
                %goto exit;
            %end;
            %else %do;
                %if %bquote(&type) ^= num %then %do;
                    %put ERROR: ���� WEIGHT ��������ֵ�ͱ�����;
                    %goto exit;
                %end;
            %end;
        %end;
        %else %do;
            %put ERROR: ���� WEIGHT = %superq(weight) ��ʽ����ȷ��;
            %goto exit;
        %end;
    %end;

    /*METHOD*/
    %if %superq(method) = %bquote() %then %do;
        %put ERROR: ���� METHOD Ϊ�գ�;
        %goto exit;
    %end;

    %let reg_method_id = %sysfunc(prxparse(%bquote(/^(AGRESTICAFFO|NEWCOMBE|EXACT|SCORE|WALD|AC|HA|MN)(?:\((CORRECT(?:=NO)?|MEE)\))?$/i)));
    %if %sysfunc(prxmatch(&reg_method_id, %superq(method))) %then %do;
        %let method_base   = %sysfunc(prxposn(&reg_method_id, 1, %superq(method)));
        %let method_adjust = %sysfunc(prxposn(&reg_method_id, 2, %superq(method)));

        /*��鲻�Ϸ�����ѡ��*/
        %let method_adjust_not_valid = FALSE;
        %if %sysfunc(find(AGRESTICAFFO|EXACT|AC|HA, &method_base)) and &method_adjust ^= %bquote() %then %do;
            %let method_adjust_not_valid = TRUE;
        %end;
        %else %if %sysfunc(find(NEWCOMBE|WALD, &method_base)) and (&method_adjust = %bquote(CORRECT=NO) or &method_adjust = MEE) %then %do;
            %let method_adjust_not_valid = TRUE;
        %end;
        %else %if %sysfunc(find(SCORE|MN, &method_base)) and &method_adjust = %bquote(CORRECT) %then %do;
            %let method_adjust_not_valid = TRUE;
        %end;

        %if &method_adjust_not_valid = TRUE %then %do;
            %put ERROR: ���� &method_base ��������ѡ�� &method_adjust ��Ч��;
            %goto exit;
        %end;
    %end;
    %else %do;
        %put ERROR: ���� METHOD = %superq(method) ��ʽ����ȷ��;
        %goto exit;
    %end;


    /*ALPHA*/
    %if %superq(alpha) = %bquote() %then %do;
        %put ERROR: ���� ALPHA Ϊ�գ�;
        %goto exit;
    %end;

    %let reg_alpha_id = %sysfunc(prxparse(%bquote(/^0?\.\d+$/)));
    %if %sysfunc(prxmatch(&reg_alpha_id, %bquote(&alpha))) %then %do;
        %if %sysevalf(%bquote(&alpha) <= 0) or %sysevalf(%bquote(&alpha) >= 1) %then %do;
            %put ERROR: ���� ALPHA ������0��1֮���һ����ֵ��;
            %goto exit;
        %end;
    %end;
    %else %do;
        %put ERROR: ���� ALPHA = %superq(alpha) ��ʽ����ȷ��;
        %goto exit;
    %end;


    /*FORMAT*/
    %if %superq(format) = %bquote() %then %do;
        %put ERROR: ���� FORMAT Ϊ�գ�;
        %goto exit;
    %end;

    %let reg_format = %bquote(/^((\$?[A-Za-z_]+(?:\d+[A-Za-z_]+)?)(?:\.|\d+\.\d*)|\$\d+\.|\d+\.\d*)$/);
    %let reg_format_id = %sysfunc(prxparse(&reg_format));
    %if %sysfunc(prxmatch(&reg_format_id, %superq(format))) %then %do;
        %let format_base = %sysfunc(prxposn(&reg_format_id, 2, %superq(format)));
        %if %bquote(&format_base) ^= %bquote() %then %do;
            proc sql noprint;
                select * from DICTIONARY.FORMATS where fmtname = "&format_base" and fmttype = "F";
            quit;
            %if &SQLOBS = 0 %then %do;
                %put ERROR: �����ʽ %superq(format) �����ڣ�;
                %goto exit;
            %end;
        %end;
    %end;
    %else %do;
        %put ERROR: ���� FORMAT = %superq(format) ��ʽ����ȷ��;
        %goto exit;
    %end;


    /*DEL_TEMP_DATA*/
    %if %superq(del_temp_data) ^= TRUE and %superq(del_temp_data) ^= FALSE %then %do;
        %put ERROR: ���� DEL_TEMP_DATA ������ TRUE �� FALSE��;
        %goto exit;
    %end;

    /*----------------------------------------------������----------------------------------------------*/
    /*1. �����������ݼ�*/
    proc sql noprint;
        create table tmp_indata as
            select
                monotonic()   as id,
                &group_var    as group,
                ifn(&group_var = &group_level_treatment, 1, 2)
                              as groupn,
                &response_var as response,
                ifn(&response_var = &response_level, 1, 2)
                              as responsen,
                %if %bquote(&weight) = #NULL %then %do;
                    1         as freq
                %end;
                %else %do;
                    &weight   as freq
                %end;
            from &libname_in..&memname_in(%superq(dataset_options_in))
            where &group_var in (&group_level_treatment, &group_level_control);
    quit;

    /*2. �����ĸ��Ƶ��������Ƶ����*/
    proc sql noprint;
        select max(0, sum(freq)) into : n11 from tmp_indata where groupn = 1 and responsen = 1; /*row 1 col 1*/
        select max(0, sum(freq)) into : n12 from tmp_indata where groupn = 1 and responsen = 2; /*row 1 col 2*/
        select max(0, sum(freq)) into : n21 from tmp_indata where groupn = 2 and responsen = 1; /*row 2 col 1*/
        select max(0, sum(freq)) into : n22 from tmp_indata where groupn = 2 and responsen = 2; /*row 2 col 2*/

        %let n10 = %eval(&n11 + &n12); /*row 1   col all*/
        %let n20 = %eval(&n21 + &n22); /*row 2   col all*/
        %let n01 = %eval(&n11 + &n21); /*row all col 1*/
        %let n02 = %eval(&n12 + &n22); /*row all col 2*/

        %let n00 = %eval(&n11 + &n12 + &n21 + &n22); /*row all col all*/
    quit;

    data tmp_indata_freq;
        rown = 1; coln = 1; freq = &n11; output;
        rown = 1; coln = 2; freq = &n12; output;
        rown = 2; coln = 1; freq = &n21; output;
        rown = 2; coln = 2; freq = &n22; output;
    run;

    %if (&n10 = 0 or &n20 = 0 or &n01 = 0 or &n02 = 0) and &method_base ^= NEWCOMBE %then %do;
        %put ERROR: �л���֮��Ϊ�㣬�����޷���������ָ������ METHOD = NEWCOMBE �� METHOD = NEWCOMBE(CORRECT)��;
        %goto exit;
    %end;

    /*3. ���� PROC FREQ �����ʲ����������*/
    data tmp_base;
        n11 = &n11; n12 = &n12; n10 = &n10;
        n21 = &n21; n22 = &n22; n20 = &n20;
        alpha = &alpha;

        p1    = n11/n10;
        p2    = n21/n20;
        pdiff = p1 - p2;
        z    = probit(1 - alpha/2);
    run;

    %if &method_base = NEWCOMBE %then %do;
        %let is_formula_delta_lt_0 = FALSE;

        data tmp_results;
            set tmp_base;

            %if &method_adjust = %bquote() %then %do;
                p1_lower   = min(p1, (2*n11 + z**2 - z*sqrt(z**2 + 4*n12*p1)) / (2*(n10 + z**2)));
                p1_upper   = max(p1, (2*n11 + z**2 + z*sqrt(z**2 + 4*n12*p1)) / (2*(n10 + z**2)));
                p2_lower   = min(p2, (2*n21 + z**2 - z*sqrt(z**2 + 4*n22*p2)) / (2*(n20 + z**2)));
                p2_upper   = max(p2, (2*n21 + z**2 + z*sqrt(z**2 + 4*n22*p2)) / (2*(n20 + z**2)));
            %end;
            %else %do;
                /*��鷽���Ƿ���ʵ����*/
                delta1 = z**2 - 2 - 1/n10 + 4*(n12 + 1)*p1;
                delta2 = z**2 + 2 - 1/n10 + 4*(n12 - 1)*p1;
                if delta1 < 0 or delta2 < 0 then do;
                    call symputx("is_formula_delta_lt_0", "TRUE");
                    stop;
                end;

                p1_lower   = min(p1, (2*n11 + z**2 - 1 - z*sqrt(z**2 - 2 - 1/n10 + 4*(n12 + 1)*p1)) / (2*(n10 + z**2)));
                p1_upper   = max(p1, (2*n11 + z**2 + 1 + z*sqrt(z**2 + 2 - 1/n10 + 4*(n12 - 1)*p1)) / (2*(n10 + z**2)));
                p2_lower   = min(p2, (2*n21 + z**2 - 1 - z*sqrt(z**2 - 2 - 1/n20 + 4*(n22 + 1)*p2)) / (2*(n20 + z**2)));
                p2_upper   = max(p2, (2*n21 + z**2 + 1 + z*sqrt(z**2 + 2 - 1/n20 + 4*(n22 - 1)*p2)) / (2*(n20 + z**2)));
            %end;

            LowerCL = p1 - p2 - sqrt((p1 - p1_lower)**2 + (p2 - p2_upper)**2);
            UpperCL = p1 - p2 + sqrt((p2 - p2_lower)**2 + (p1 - p1_upper)**2);
        run;

        %if &is_formula_delta_lt_0 = TRUE %then %do;
            %put ERROR: ������������� Newcombe-Wilson ������У�����������䷽��ʱ��ʵ���⣬������� ALPHA �Ƿ���ʣ���ʹ�ò�У���� Newcombe-Wilson ������;
            %put WARNING: һ������£����ڵ����� < 10% �� > 90% ������£���Ҫʹ�� Newcombe-Wilson ������У����;
            %goto exit;
        %end;
    %end;
    %else %do;
        ods html close;
        ods output PdiffCLs     = tmp_pdiffcls(keep = LowerCL UpperCL)
                   RiskDiffCol1 = tmp_riskdiffcol1;
        proc freq data = tmp_indata_freq;
            tables rown*coln / riskdiff(cl = &method) alpha = &alpha;
            %if &method_base = EXACT %then %do;
                exact riskdiff;
            %end;
            weight freq / zeros;
        run;
        ods html;

        data tmp_results;
            merge tmp_base
                  %if &method_base = EXACT %then %do;
                      tmp_riskdiffcol1(firstobs = 1 obs = 1 keep = ExactLowerCL ExactUpperCL rename = (ExactLowerCL = p1_lower ExactUpperCL = p1_upper))
                      tmp_riskdiffcol1(firstobs = 2 obs = 2 keep = ExactLowerCL ExactUpperCL rename = (ExactLowerCL = p2_lower ExactUpperCL = p2_upper))
                  %end;
                  %else %do;
                      tmp_riskdiffcol1(firstobs = 1 obs = 1 keep = LowerCL UpperCL rename = (LowerCL = p1_lower UpperCL = p1_upper))
                      tmp_riskdiffcol1(firstobs = 2 obs = 2 keep = LowerCL UpperCL rename = (LowerCL = p2_lower UpperCL = p2_upper))
                  %end;
                  tmp_pdiffcls;
        run;
    %end;

    /*4. ����������ݼ�*/
    proc sql noprint;
        select Pdiff   format = &format into : Pdiff   trimmed from tmp_results;
        select LowerCL format = &format into : LowerCL trimmed from tmp_results;
        select UpperCL format = &format into : UpperCL trimmed from tmp_results;
    quit;

    data tmp_outdata;
        item = %unquote(&stat_note_quote);

        set tmp_results;
        value = "&Pdiff(&LowerCL, &UpperCL)";

        attrib _all_ label = "";
    run;


    /*5. ������ݼ�*/
    data &libname_out..&memname_out(%if %superq(dataset_options_out) = %bquote() %then %do;
                                        keep = item value
                                    %end;
                                    %else %do;
                                        &dataset_options_out
                                    %end;);
        set tmp_outdata;
    run;

    /*----------------------------------------------���к���----------------------------------------------*/
    /*ɾ���м����ݼ�*/
    %exit_with_tempdata_created:
    %if %superq(del_temp_data) = TRUE %then %do;
        proc datasets noprint nowarn;
            delete tmp_indata
                   tmp_indata_freq
                   tmp_base
                   tmp_riskdiffcol1
                   tmp_pdiffcls
                   tmp_results
                   tmp_outdata
                   ;
        quit;
    %end;

    %exit:
    %put NOTE: �� RiskDiff �ѽ������У�;
%mend;
