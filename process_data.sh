
set -e
DATA="test_data"
RAW_DATA="$DATA/raw_data"
CLEAN_DATA="$DATA/clean_data"
SPM_DATA="$DATA/spm_data"
BPE_DATA="$DATA/bpe_data"
DATA_BIN="$DATA/data-bin"

CODES=6000

# tools
MAIN="$PWD"
TOOLS_PATH="$MAIN/tools/preprocess_tools"
SPM_TRAIN=$TOOLS_PATH/spm_train
SPM_ENCODE=$TOOLS_PATH/spm_encode
NORM_PUNC=$TOOLS_PATH/normalize-punctuation.perl
REPLACE_UNICODE_PUNCT=$TOOLS_PATH/replace-unicode-punctuation.perl
REM_NON_PRINT_CHAR=$TOOLS_PATH/remove-non-printing-char.perl
INPUT_FROM_SGM=$TOOLS_PATH/input-from-sgm.perl

# clean tools
CLEAN_TOOLS=$MAIN/tools/clean_tools
DEDUP_MONO=$CLEAN_TOOLS/deduplicate_mono.py

###################################################################
# 1. normalize/clean raw data
mkdir -p $CLEAN_DATA

PREPROCESSING="$REM_NON_PRINT_CHAR"
lang_pairs=`ls $RAW_DATA`

for split in "train" "valid" "test"; do
    for lang_pair in $lang_pairs; do
        pair_arr=(${lang_pair//-/ })
        src_lang=${pair_arr[0]}
        tgt_lang=${pair_arr[1]}

        mkdir -p $CLEAN_DATA/$lang_pair
        cat $RAW_DATA/$lang_pair/$split.$src_lang | $PREPROCESSING > $CLEAN_DATA/$lang_pair/$split.$src_lang
        cat $RAW_DATA/$lang_pair/$split.$tgt_lang | $PREPROCESSING > $CLEAN_DATA/$lang_pair/$split.$tgt_lang
    done
done
###################################################################

# 2. tokenize
mkdir -p $SPM_DATA

# gather train data
for lang_pair in $lang_pairs; do
    pair_arr=(${lang_pair//-/ })
    src_lang=${pair_arr[0]}
    tgt_lang=${pair_arr[1]}

    cat $CLEAN_DATA/$lang_pair/train.$src_lang $CLEAN_DATA/$lang_pair/train.$tgt_lang
done > $SPM_DATA/spm_data

# deduplicate
python $DEDUP_MONO --rec-file $SPM_DATA/spm_data --out-file $SPM_DATA/spm_data.dedup

# train spm model
spm_train \
--normalization_rule_name identity \
--input $SPM_DATA/spm_data.dedup \
--model_prefix $SPM_DATA/spm \
--vocab_size ${CODES} \
--character_coverage 1.0 \
--model_type bpe

# encode spm_data to obtain vocabulary
spm_encode --model $SPM_DATA/spm.model --output_format piece < $SPM_DATA/spm_data.dedup > $SPM_DATA/spm_data.spm
fairseq-preprocess \
    --trainpref $SPM_DATA/spm_data.spm \
    --destdir $SPM_DATA \
    --workers 12 \
    --only-source \
    --dict-only

###################################################################
# 3. encode and binary
mkdir -p $BPE_DATA


for split in "train" "valid" "test"; do
    for lang_pair in $lang_pairs; do
        pair_arr=(${lang_pair//-/ })
        src_lang=${pair_arr[0]}
        tgt_lang=${pair_arr[1]}

        mkdir -p $BPE_DATA/$lang_pair

        spm_encode --model $SPM_DATA/spm.model \
            --output_format piece < $CLEAN_DATA/$lang_pair/$split.$src_lang > $BPE_DATA/$lang_pair/$split.$src_lang
        
        spm_encode --model $SPM_DATA/spm.model \
            --output_format piece < $CLEAN_DATA/$lang_pair/$split.$tgt_lang > $BPE_DATA/$lang_pair/$split.$tgt_lang
    done
done

mkdir -p $DATA_BIN
dict=$SPM_DATA/dict.txt

for lang_pair in $lang_pairs; do
    pair_arr=(${lang_pair//-/ })
    src_lang=${pair_arr[0]}
    tgt_lang=${pair_arr[1]}

    fairseq-preprocess \
        --source-lang ${src_lang} \
        --target-lang ${tgt_lang} \
        --srcdict $dict \
        --tgtdict $dict \
        --testpref $BPE_DATA/$lang_pair/test \
        --destdir $DATA_BIN \
        --workers 4 \

    fairseq-preprocess \
        --source-lang ${src_lang} \
        --target-lang ${tgt_lang} \
        --srcdict $dict \
        --tgtdict $dict \
        --validpref $BPE_DATA/$lang_pair/valid \
        --destdir $DATA_BIN \
        --workers 4 \
    
    fairseq-preprocess \
        --source-lang ${src_lang} \
        --target-lang ${tgt_lang} \
        --srcdict $dict \
        --tgtdict $dict \
        --trainpref $BPE_DATA/$lang_pair/train \
        --destdir $DATA_BIN \
        --workers 16 \

done
        






# for lang in "$src" "$tgt"; do
#     PREPROCESSING="$REPLACE_UNICODE_PUNCT | $NORM_PUNC -l $lang | $REM_NON_PRINT_CHAR"
#     if [ ! -f "$DATA/$split.$lang.norm" ]; then
#         cat $DATA/$split.$lang | $PREPROCESSING > $DATA/$split.$lang.norm
#     fi

#     if [ $lang != "zh" ]; then
#     $SPM_ENCODE \
#     --model /data1/lsj/image_translation/text_data/data/spm_model/$lang.model \
#     --output_format=piece \
#     --input $DATA/$split.$lang.norm \
#     --output $DATA/$split.spm.$lang
#     fi
# done

# fairseq-preprocess \
#     --source-lang "$src" --target-lang "$tgt" \
#     --testpref $DATA/$split.spm \
#     --destdir $DATA \
#     --workers 12 \
#     --srcdict $DATA/dict.$src.txt \
#     --tgtdict $DATA/dict.$tgt.txt \

# fairseq-preprocess \
#     --source-lang "en" --target-lang "fr" \
#     --validpref $DATA/valid.spm \
#     --destdir $DATA \
#     --workers 12 \
#     --srcdict $DATA/dict.en.txt \
#     --tgtdict $DATA/dict.fr.txt

# $SPM_ENCODE \
#     --model /data/lsj/nfs/it_experiment/data/general_data/text_data/spm_model/fr.model \
#     --output_format=piece \
#     --input $DATA/valid.fr.norm \
#     --output $DATA/valid.spm.fr

# $SPM_ENCODE \
#     --model /data/lsj/nfs/it_experiment/data/general_data/text_data/spm_model/ru.model \
#     --output_format=piece \
#     --input $DATA/train.ru.norm \
#     --output $DATA/train.spm.ru

#spm model
# source_model="/data/lsj/nfs/it_experiment/data/syn_data_en/spm_model/english.model"
# target_model="/data/lsj/nfs/it_experiment/data/syn_data_en/spm_model/chinese.model"

# if [ ! -f "$DATA/spm_model/english.model" ]; then
#     echo "Starting sentencepiece training..."
#     $SPM_TRAIN \
#     --input=$DATA/train.en.norm \
#     --model_prefix=$DATA/spm_model/english.model \
#     --vocab_size=$CODES \
#     --character_coverage=1.0 \
#     --model_type=bpe
# fi

# if [ ! -f "$DATA/spm_model/chinese.model" ]; then
#     echo "Starting sentencepiece training..."
#     $SPM_TRAIN \
#     --input=$DATA/train.zh.norm \
#     --model_prefix=$DATA/spm_model/chinese.model \
#     --vocab_size=$CODES \
#     --character_coverage=1.0 \
#     --model_type=bpe
# fi

# $SPM_ENCODE \
#     --model $english_model \
#     --output_format=piece \
#     --input $DATA/train.en.norm \
#     --output $DATA/train.spm.en

# $SPM_ENCODE \
#     --model $english_model \
#     --output_format=piece \
#     --input $DATA/valid.en.norm \
#     --output $DATA/valid.spm.en






# normalize
# if [ ! -f "$DATA/train.en.norm" ]; then
#     cat $DATA/train.zh | $PREPROCESSING > $DATA/train.zh.norm
#     cat $DATA/train.en | $PREPROCESSING > $DATA/train.en.norm
# fi


# if [ ! -f "$DATA/valid.en.norm" ]; then
#     wmt_path=/data/lsj/sixt/acl22-sixtp/raw/valid_test_set/wmt/dev/sgm
#     eval "cat $wmt_path/newstest2017-zhen-src.zh.sgm | $PREPROCESSING_VALID > $DATA/valid.zh.norm"
#     eval "cat $wmt_path/newstest2017-zhen-ref.en.sgm | $PREPROCESSING_VALID > $DATA/valid.en.norm"
# fi

# # train spm
# if [ ! -f "$DATA/spm_model/english.model" ]; then
#     echo "Starting sentencepiece training..."
#     $SPM_TRAIN \
#     --input=$DATA/train.en.norm \
#     --model_prefix=$DATA/spm_model/english.model \
#     --vocab_size=$CODES \
#     --character_coverage=1.0 \
#     --model_type=bpe
# fi

# if [ ! -f "$DATA/spm_model/chinese.model" ]; then
#     echo "Starting sentencepiece training..."
#     $SPM_TRAIN \
#     --input=$DATA/train.zh.norm \
#     --model_prefix=$DATA/spm_model/chinese.model \
#     --vocab_size=$CODES \
#     --character_coverage=1.0 \
#     --model_type=bpe
# fi

# spm encode

# if [ ! -f "$DATA/train.zh-en.spm.en" ]; then
#     # $SPM_ENCODE \
#     #     --model $english_model \
#     #     --output_format=piece \
#     #     --input $DATA/train.en.norm \
#     #     --output $DATA/train.zh-en.spm.en

#     # $SPM_ENCODE \
#     #     --model $DATA/spm_model/chinese.model \
#     #     --output_format=piece \
#     #     --input $DATA/train.zh.norm \
#     #     --output $DATA/train.zh-en.spm.zh

    
# fi





# if [ ! -f "$DATA/valid.zh-en.spm.en" ]; then
#     $SPM_ENCODE \
#         --model $english_model \
#         --output_format=piece \
#         --input $DATA/valid.en.norm \
#         --output $DATA/valid.zh-en.spm.en

    # $SPM_ENCODE \
    #     --model $DATA/spm_model/chinese.model \
    #     --output_format=piece \
    #     --input $DATA/valid.zh.norm \
    #     --output $DATA/valid.zh-en.spm.zh
# fi

# $SPM_ENCODE \
#     --model $chinese_model \
#     --output_format=piece \
#     --input $DATA/test.zh.norm \
#     --output $DATA/test.spm.zh

# obtain dict


#binary
# if [ ! -f "$DATA/train.en-fr.en.bin" ]; then
#     fairseq-preprocess \
#         --source-lang "en" --target-lang "fr"\
#         --trainpref $DATA/train.en-fr.spm \
#         --destdir $DATA \
#         --workers 12 
# fi

# if [ ! -f "$DATA/valid.en-fr.en.bin" ]; then
#     fairseq-preprocess \
#             --source-lang "en" --target-lang "fr"\
#             --validpref $DATA/valid.en-fr.spm  \
#             --destdir $DATA \
#             --workers 4 \
#             --srcdict $DATA/dict.en.txt \
#             --tgtdict $DATA/dict.fr.txt 
# fi


