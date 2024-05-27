/*
===================================
Macro Name: BinomialCI
Macro Label: 率（构成比）及其置信区间
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
                  /des = "率（构成比）及其置信区间" parmbuff;

    /*打开帮助文档*/
    %if %qupcase(%superq(SYSPBUFF)) = %bquote((HELP)) or %qupcase(%superq(SYSPBUFF)) = %bquote(()) %then %do;
        X explorer "https://github.com/Snoopy1866/FreqStatKit/blob/main/docs/BinomialCI/readme.md";
        %goto exit;
    %end;

    /*----------------------------------------------初始化----------------------------------------------*/
    /*统一参数大小写*/
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

    /*统计量对应的输出格式*/
    %let GLOBAL_format = percentn9.2;
    %let RATE_format   = &GLOBAL_format;
    %let CLM_format    = &GLOBAL_format;
    %let LCLM_format   = &CLM_format;
    %let UCLM_format   = &CLM_format;

    /*声明局部变量*/
    %local i j;

    /*----------------------------------------------参数检查----------------------------------------------*/
    /*INDATA*/
    %if %superq(indata) = %bquote() %then %do;
        %put ERROR: 未指定分析数据集！;
        %goto exit;
    %end;
    %else %do;
        %let reg_indata_id = %sysfunc(prxparse(%bquote(/^(?:([A-Za-z_][A-Za-z_\d]*)\.)?([A-Za-z_][A-Za-z_\d]*)(?:\((.*)\))?$/)));
        %if %sysfunc(prxmatch(&reg_indata_id, %superq(indata))) = 0 %then %do;
            %put ERROR: 参数 INDATA = %superq(indata) 格式不正确！;
            %goto exit;
        %end;
        %else %do;
            %let libname_in = %upcase(%sysfunc(prxposn(&reg_indata_id, 1, &indata)));
            %let memname_in = %upcase(%sysfunc(prxposn(&reg_indata_id, 2, &indata)));
            %let dataset_options_in = %sysfunc(prxposn(&reg_indata_id, 3, &indata));
            %if &libname_in = %bquote() %then %let libname_in = WORK; /*未指定逻辑库，默认为WORK目录*/
            proc sql noprint;
                select * from DICTIONARY.MEMBERS where libname = "&libname_in";
            quit;
            %if &SQLOBS = 0 %then %do;
                %put ERROR: &libname_in 逻辑库不存在！;
                %goto exit;
            %end;
            proc sql noprint;
                select * from DICTIONARY.MEMBERS where libname = "&libname_in" and memname = "&memname_in";
            quit;
            %if &SQLOBS = 0 %then %do;
                %put ERROR: 在 &libname_in 逻辑库中没有找到 &memname_in 数据集！;
                %goto exit;
            %end;
        %end;
    %end;
    %put NOTE: 分析数据集被指定为 &libname_in..&memname_in;


    %let IS_COND_SPECIFIED = TRUE;
    /*COND_POS*/
    %if %superq(cond_pos) = %bquote() %then %do;
        %put ERROR: 参数 COND_POS 为空！;
        %let IS_COND_SPECIFIED = FALSE;
    %end;


    /*COND_POS*/
    %if %superq(cond_neg) = %bquote() %then %do;
        %put ERROR: 参数 COND_NEG 为空！;
        %let IS_COND_SPECIFIED = FALSE;
    %end;

    %if &IS_COND_SPECIFIED = FALSE %then %do;
        %goto exit;
    %end;


    /*STAT_NOTE*/
    %if %superq(stat_note) = %bquote() %then %do;
        %put ERROR: 参数 STAT_NOTE 为空！;
        %goto exit;
    %end;

    %let reg_stat_note_id = %sysfunc(prxparse(%bquote(/^(\x22[^\x22]*\x22|\x27[^\x27]*\x27)$/)));
    %if %sysfunc(prxmatch(&reg_stat_note_id, %superq(stat_note))) %then %do;
        %let stat_note_quote = %superq(stat_note);
    %end;
    %else %do;
        %put ERROR: 参数 STAT_NOTE 格式不正确，指定的字符串必须使用匹配的引号包围！;
        %goto exit;
    %end;


    /*OUTDATA*/
    %if %superq(outdata) = %bquote() %then %do;
        %put ERROR: 参数 OUTDATA 为空！;
        %goto exit;
    %end;
    %else %do;
        %if %bquote(%upcase(&outdata)) = %bquote(#AUTO) %then %do;
            %let outdata = RES_&var_name;
        %end;
 
        %let reg_outdata_id = %sysfunc(prxparse(%bquote(/^(?:([A-Za-z_][A-Za-z_\d]*)\.)?([A-Za-z_][A-Za-z_\d]*)(?:\((.*)\))?$/)));
        %if %sysfunc(prxmatch(&reg_outdata_id, %superq(outdata))) = 0 %then %do;
            %put ERROR: 参数 OUTDATA = %superq(outdata) 格式不正确！;
            %goto exit;
        %end;
        %else %do;
            %let libname_out = %upcase(%sysfunc(prxposn(&reg_outdata_id, 1, &outdata)));
            %let memname_out = %upcase(%sysfunc(prxposn(&reg_outdata_id, 2, &outdata)));
            %let dataset_options_out = %sysfunc(prxposn(&reg_outdata_id, 3, &outdata));
            %if &libname_out = %bquote() %then %let libname_out = WORK; /*未指定逻辑库，默认为WORK目录*/
            proc sql noprint;
                select * from DICTIONARY.MEMBERS where libname = "&libname_out";
            quit;
            %if &SQLOBS = 0 %then %do;
                %put ERROR: &libname_out 逻辑库不存在！;
                %goto exit;
            %end;
        %end;
        %put NOTE: 输出数据集被指定为 &libname_out..&memname_out;
    %end;


    /*WEIGHT*/
    %if %superq(weight) ^= #NULL %then %do;
        %let reg_weight_id = %sysfunc(prxparse(%bquote(/^[A-Za-z_][A-Za-z_\d]*$/)));
        %if %sysfunc(prxmatch(&reg_weight_id, %superq(weight))) = 0 %then %do;
            %put ERROR: 参数 WEIGHT = %bquote(&weight) 格式不正确！;
            %goto exit;
        %end;
        %else %do;
            proc sql noprint;
                select type into :type from DICTIONARY.COLUMNS where libname = "&libname_in" and memname = "&memname_in" and upcase(name) = "&weight";
            quit;
            %if &SQLOBS = 0 %then %do; /*数据集中没有找到变量*/
                %put ERROR: 在 &libname_in..&memname_in 中没有找到权重变量 &weight;
                %goto exit;
            %end;
            %else %do;
                %if %bquote(&type) ^= num %then %do;
                    %put ERROR: 参数 WEIGHT 指定的权重变量 %bquote(&weight) 不是数值型的！;
                    %goto exit;
                %end;
            %end;
        %end;
    %end;


    /*ADJUST_METHOD*/
    %if %superq(adjust_method) = %bquote() %then %do;
        %put ERROR: 参数 ADJUST_METHOD 为空！;
        %goto exit;
    %end;

    %if %superq(adjust_method) = #NULL %then %do;
        %put NOTE: 未指定校正方法，默认使用 WALD 法计算置信区间！;
    %end;
    %else %do;
        %let reg_adjust_method_id = %sysfunc(prxparse(%bquote(/^(?:WILSON\(CORRECT\)|SCORE\(CORRECT\)|LIKELIHOODRATIO|CLOPPERPEARSON|AGRESTICOULL|JEFFREYS|SCOREC|WILSONC|BLAKER|WILSON|EXACT|LOGIT|SCORE|MIDP|LOG|AC|CP|LR|MP|J)$/)));
        %if %sysfunc(prxmatch(&reg_adjust_method_id, %superq(adjust_method))) = 0 %then %do;
            %put ERROR: 参数 ADJUST_METHOD 指定的校正方法 %superq(ADJUST_METHOD) 不存在或不受支持，受支持的校正方法如下：;
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
            %put WARNING: 未指定校正方法，参数 ADJUST_THRESHOLD 已被忽略！;
        %end;
    %end;
    %else %do;
        %if %superq(adjust_threshold) = #AUTO %then %do;
            %put NOTE: 未指定校正条件，默认当构成比（率）大于或等于0.9时对置信区间进行校正！;
            %let adjust_threshold = %bquote(#RATE >= 0.9);
            %let adjust_threshold_cond_expr = %nrstr(&RATE >= 0.9);
        %end;
        %else %do;
            %let reg_adjust_threshold_id = %sysfunc(prxparse(%bquote(/^\(*\s?#(RATE|LCLM|UCLM)\s?(NE|\^=|~=|GE|>=|LE|<=|GT|>|LT|<|EQ|=)\s?(\d+(?:\.\d+)?)\s?\)*(?:\s(AND|OR|&|\|)\s\(*\s?#(RATE|LCLM|UCLM)\s?(NE|\^=|~=|GE|>=|LE|<=|GT|>|LT|<|EQ|=)\s?(\d+(?:\.\d+)?)\s?\)*)*$/)));
            %if %sysfunc(prxmatch(&reg_adjust_threshold_id, %superq(adjust_threshold))) = 0 %then %do;
                %put ERROR: 参数 ADJUST_THRESHOLD = %superq(adjust_threshold) 格式不正确！;
                %goto exit;
            %end;
            %else %do;
                %if %sysfunc(count(%bquote(adjust_threshold), %bquote(%str(%()))) = %sysfunc(count(%bquote(adjust_threshold), %bquote(%str(%))))) %then %do;
                    %let adjust_threshold_cond_expr = %nrstr(%sysfunc(transtrn(%bquote(&adjust_threshold), %bquote(#), %nrbquote(&)))); /*校正条件对应的宏表达式*/
                %end;
                %else %do;
                    %put ERROR: 参数 ADJUST_THRESHOLD = %bquote(&adjust_threshold) 括号不匹配！;
                    %goto exit;
                %end;
            %end;
        %end;
    %end;


    /*ALPHA*/
    %if %superq(alpha) = %bquote() %then %do;
        %put ERROR: 参数 ALPHA 为空！;
        %goto exit;
    %end;

    %let reg_alpha_id = %sysfunc(prxparse(%bquote(/^0?\.\d+$/)));
    %if %sysfunc(prxmatch(&reg_alpha_id, %superq(alpha))) = 0 %then %do;
        %put ERROR: 参数 ALPHA 格式不正确！;
        %goto exit;
    %end;
    %else %do;
        %if %sysevalf(%bquote(&alpha) <= 0) or %sysevalf(%bquote(&alpha) >= 1) %then %do;
            %put ERROR: 参数 ALPHA 必须是0和1之间的一个数值！;
            %goto exit;
        %end;
    %end;


    /*FORMAT*/
    %macro temp_format_update(format_2be_update, format_new); /*更新统计量输出格式的内部宏程序*/
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
        %put ERROR: 参数 FORMAT 为空！;
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
            %let format_index_&i = %sysfunc(prxposn(&reg_format_unit_id, 1, %bquote(&&format_part_&i))); /*第i个修改格式的指标名称*/
            %let format_&i = %sysfunc(prxposn(&reg_format_unit_id, 2, %bquote(&&format_part_&i))); /*第i个格式名称*/
            %let fomrat_&i._base = %sysfunc(prxposn(&reg_format_unit_id, 3, %bquote(&&format_part_&i))); /*第i个格式名称的base名称*/

            %if %bquote(&&format_index_&i) = %bquote() %then %do; /*未指定修改格式的统计量名称，默认全局修改*/
                %let format_index_&i = GLOBAL;
            %end;
            %if %bquote(&&fomrat_&i._base) = %bquote() %then %do; /*指定的简单格式，直接修改*/
                %temp_format_update(&&format_index_&i, &&format_&i);
            %end;
            %else %do; /*指定的其他格式，需要进一步判断格式的存在性*/
                proc sql noprint;
                    select * from DICTIONARY.FORMATS where fmtname = "&&fomrat_&i._base" and fmttype = "F";
                quit;
                %if &SQLOBS = 0 %then %do;
                    %put ERROR: 为统计量 &&format_index_&i 指定的输出格式 &&format_&i 不存在！;
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
        %put ERROR: 参数 DEL_TEMP_DATA 必须是 TRUE 或 FALSE！;
        %goto exit;
    %end;

    /*----------------------------------------------主程序----------------------------------------------*/
    /*1. 复制分析数据*/
    proc sql noprint;
        create table temp_indata as
            select * from &libname_in..&memname_in(&dataset_options_in);
    quit;


    /*2. 频数计数*/
    %if %bquote(&weight) = %bquote(#NULL) %then %do;
        proc sql noprint;
            select count(*) into: pos_n from temp_indata where &cond_pos; /*“成功”的例数*/
            select count(*) into: neg_n from temp_indata where &cond_neg; /*“失败”的例数*/
        quit;
    %end;
    %else %do;
        proc sql noprint;
            select sum(&weight) into: pos_n from temp_indata where &cond_pos; /*“成功”的例数*/
            select sum(&weight) into: neg_n from temp_indata where &cond_neg; /*“失败”的例数*/
        quit;
    %end;

    %if &SYSERR > 0 %then %do;
        %put ERROR: 在尝试计算频数时出现错误，导致错误的原因是参数 COND_POS 或 COND_NEG 语法错误！;
        %goto exit_with_error_in_sqlcond;
    %end;

    /*“成功”和“失败”的频数均为0，无法计算置信区间时，提前结束计算*/
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


    /*3. 构建“成功”和“失败”频数的数据集*/
    proc sql noprint;
        create table temp_freq (orres char(200), n num);
        insert into temp_freq
            values("positive", &pos_n)
            values("negative", &neg_n);
    quit;


    /*4. 计算率及其置信区间*/
    proc freq data = temp_freq noprint;
        tables orres /binomial(level = "positive" wald %if %bquote(&adjust_method) ^= #NULL %then %do;
                                                           &adjust_method
                                                       %end;) alpha = &alpha missing;
        weight n /zeros;
        output out = temp_ci binomial;
    quit;

    /*5. 根据是否指定校正方法以及校正条件，提取率及其置信区间*/
    proc sql noprint;
        select _BIN_ format = 16.14 into :RATE from temp_ci;
        select L_BIN format = 16.14 into :LCLM from temp_ci;
        select U_BIN format = 16.14 into :UCLM from temp_ci;
    quit;
    %if %bquote(&adjust_method) ^= #NULL %then %do; /*指定了校正方法*/
        proc sql noprint;
            %if %sysevalf(%unquote(&adjust_threshold_cond_expr)) %then %do;
                %put NOTE: 校正条件 %unquote(&adjust_threshold_cond_expr) 成立，将使用 &adjust_method 法对置信区间进行校正！;
                /*校正条件满足，提取校正方法计算的置信区间*/
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
                /*校正条件不满足，提取WALD法计算的置信区间*/
                select _BIN_ format = &RATE_format into :RATE_FMT from temp_ci;
                select L_BIN format = &LCLM_format into :LCLM_FMT from temp_ci;
                select U_BIN format = &UCLM_format into :UCLM_FMT from temp_ci;
            %end;
        quit;
    %end;
    %else %do; /*未指定校正方法*/
        proc sql noprint;
            select _BIN_ format = &RATE_format into :RATE_FMT from temp_ci;
            select L_BIN format = &LCLM_format into :LCLM_FMT from temp_ci;
            select U_BIN format = &UCLM_format into :UCLM_FMT from temp_ci;
        quit;
    %end;
    %let rate_and_ci = %bquote(%sysfunc(strip(&RATE_FMT))(%sysfunc(strip(&LCLM_FMT)), %sysfunc(strip(&UCLM_FMT))));


    /*6. 构建输出数据集*/
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


    /*7. 输出数据集*/
    data &libname_out..&memname_out(%if %bquote(&dataset_options_out) = %bquote() %then %do;
                                        keep = item value
                                    %end;
                                    %else %do;
                                        &dataset_options_out
                                    %end;);
        set temp_out;
    run;

    /*----------------------------------------------运行后处理----------------------------------------------*/
    %exit_with_error_in_sqlcond:
    /*删除中间数据集*/
    %if %superq(del_temp_data) = TRUE %then %do;
        proc datasets noprint nowarn;
            delete temp_indata
                   temp_freq
                   temp_ci
                   temp_out
                   ;
        quit;
    %end;

    /*删除临时宏*/
    proc catalog catalog = work.sasmacr;
        delete temp_format_update.macro;
    quit;

    %exit:
    %put NOTE: 宏 BinomialCI 已结束运行！;
%mend;
