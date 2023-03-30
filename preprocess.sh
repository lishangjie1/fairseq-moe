#!/bin/bash
set -e
wmt_valid_and_test_preprocess(){
    input_prefix=$1
    output_prefix=$2
    lang=$3
    REPLACE_UNICODE_PUNCT=$WORKLOC/scripts/tools/replace-unicode-punctuation.perl
    NORM_PUNC=$WORKLOC/scripts/tools/normalize-punctuation.perl
    REM_NON_PRINT_CHAR=$WORKLOC/scripts/tools/remove-non-printing-char.perl
    INPUT_FROM_SGM=$WORKLOC/scripts/tools/input-from-sgm.perl
    src=$input_prefix-src.$lang.sgm
    ref=$input_prefix-ref.en.sgm
    output_src=$output_prefix.$lang
    output_ref=$output_prefix.en
    PREPROCESSING="$INPUT_FROM_SGM | $REPLACE_UNICODE_PUNCT | $NORM_PUNC -l $lang | $REM_NON_PRINT_CHAR"
    eval "cat $src | $PREPROCESSING > $output_src"
    eval "cat $ref | $PREPROCESSING > $output_ref"
}
preprocess_dataset(){
    input=$1
    output=$2
    lang=$3
    REPLACE_UNICODE_PUNCT=$WORKLOC/scripts/tools/replace-unicode-punctuation.perl
    NORM_PUNC=$WORKLOC/scripts/tools/normalize-punctuation.perl
    REM_NON_PRINT_CHAR=$WORKLOC/scripts/tools/remove-non-printing-char.perl
    if [ $lang != 'de' -a $lang != 'es' -a $lang != 'cz' -a $lang != 'fr' -a $lang != 'en' ]; then
        case $lang in
        "deu")
            lang="de"
            ;;
        "spa")
            lang="es"
            ;;
        "ces")
            lang="cz"
            ;;
        "fra")
            lang="fr"
            ;;    
        *)
            lang="en"
        esac
    fi
    echo "preprocessing $input as $lang"
    PREPROCESSING="$REPLACE_UNICODE_PUNCT | $NORM_PUNC -l $lang | $REM_NON_PRINT_CHAR"
    eval "cat $input | $PREPROCESSING > $output"
}
preprocess_datasets(){
    tgt=en
    raw=$WORKLOC/raw
    mkdir -p $raw
    
    for src in 'de' 'es' 'fi' 'hi' 'ru' 'zh'; do
        mkdir -p $raw/$src
        for lang in "$src" "en"; do
            if [ ! -f "$raw/$src/train.$src-en.$lang" ]; then
                preprocess_dataset $raw/$src/all.$lang $raw/$src/train.$src-en.$lang $lang
            fi
        done
    done

    # valid and test set
    declare -A dic
    #wmt prefix, end with sgm
    wmt_path="$WORKLOC/raw/valid_test_set/wmt/dev/sgm"
    dic['valid.de-en']=$wmt_path/newstest2016-deen
    dic['valid.es-en']=$wmt_path/newstest2010
    dic['valid.fi-en']=$wmt_path/newstest2019-fien
    dic['valid.hi-en']=$wmt_path/newsdev2014
    dic['valid.ru-en']=$wmt_path/newstest2016-ruen
    dic['valid.zh-en']=$wmt_path/newstest2017-zhen
    for lang in "de" "es" "fi" "hi" "ru" "zh"; do
        mkdir -p $raw/$lang
        key="valid.$lang-en"
        wmt_valid_and_test_preprocess ${dic[$key]} $raw/$lang/$key "$lang"
    done

    dic['test.de-en']=$wmt_path/newstest2014-deen
    dic['test.es-en']=$wmt_path/newstest2013
    dic['test.et-en']=$wmt_path/newstest2018-eten
    dic['test.fi-en']=$wmt_path/newstest2016-fien
    dic['test.gu-en']=$wmt_path/newstest2019-guen
    dic['test.hi-en']=$wmt_path/newstest2014-hien
    dic['test.ja-en']=$wmt_path/newstest2020-jaen
    dic['test.kk-en']=$wmt_path/newstest2019-kken
    dic['test.km-en']=$wmt_path/newstest2020-kmen
    dic['test.lv-en']=$wmt_path/newstest2017-lven
    dic['test.pl-en']=$wmt_path/newstest2020-plen
    dic['test.ps-en']=$wmt_path/newstest2020-psen
    dic['test.ro-en']=$wmt_path/newstest2016-roen
    dic['test.ru-en']=$wmt_path/newstest2020-ruen
    dic['test.tr-en']=$wmt_path/newstest2016-tren
    dic['test.zh-en']=$wmt_path/newstest2018-zhen
    for lang in "de" "es" "et" "fi" "gu" "hi" "ja" "kk" "km" "lv" "pl" "ps" "ro" "ru" "tr" "zh"; do
        mkdir -p $raw/$lang
        key="test.$lang-en"
        wmt_valid_and_test_preprocess ${dic[$key]} $raw/$lang/$key "$lang"
    done

    

    #other valid and test set
    #IWSLT
    iwslt_path="$WORKLOC/raw/valid_test_set/2017-01-ted-test/texts"
    mkdir -p $raw/ar
    preprocess_dataset $iwslt_path/ar/en/ar-en/test.ar-en.ar $raw/ar/test.ar-en.ar "ar"
    preprocess_dataset $iwslt_path/en/ar/en-ar/test.ar-en.en $raw/ar/test.ar-en.en "ar"
    #Tatoeba
    tatoeba_path="$WORKLOC/raw/valid_test_set/data/test-v2020-07-28"
    test_iten=$tatoeba_path/eng-ita/test.txt
    test_koen=$tatoeba_path/eng-kor/test.txt
    test_nlen=$tatoeba_path/eng-nld/test.txt

    mkdir -p $raw/it
    python $WORKLOC/scripts/tools/extract_tatoeba.py $test_iten $raw/it/test.en $raw/it/test.it
    preprocess_dataset $raw/it/test.it $raw/it/test.it-en.it "it"
    preprocess_dataset $raw/it/test.en $raw/it/test.it-en.en "en"
     

    mkdir -p $raw/ko
    python $WORKLOC/scripts/tools/extract_tatoeba.py $test_koen $raw/ko/test.en $raw/ko/test.ko
    preprocess_dataset $raw/ko/test.ko $raw/ko/test.ko-en.ko "ko"
    preprocess_dataset $raw/ko/test.en $raw/ko/test.ko-en.en "en"

    mkdir -p $raw/nl
    python $WORKLOC/scripts/tools/extract_tatoeba.py $test_nlen $raw/nl/test.en $raw/nl/test.nl
    preprocess_dataset $raw/nl/test.nl $raw/nl/test.nl-en.nl "nl"
    preprocess_dataset $raw/nl/test.en $raw/nl/test.nl-en.en "en"


    #Flores v1
    flores_path="$WORKLOC/raw/valid_test_set/flores_test_sets"
    test_sien=$flores_path/wikipedia.test.si-en
    test_neen=$flores_path/wikipedia.test.ne-en

    mkdir -p $raw/si
    preprocess_dataset $test_sien.si $raw/si/test.si-en.si "si"
    preprocess_dataset $test_sien.en $raw/si/test.si-en.en "en"

    mkdir -p $raw/ne
    preprocess_dataset $test_neen.ne $raw/ne/test.ne-en.ne "ne"
    preprocess_dataset $test_neen.en $raw/ne/test.ne-en.en "en"


}



binarize_fairseq_dataset(){
    raw=$WORKLOC/raw
    bpe=$WORKLOC/bpe
    fseq=/data/lsj/nfs/fseq1

    # raw="/data1/lsj/new_spm_supervised/raw"
    # bpe="/data1/lsj/new_spm_supervised/bpe"
    # fseq="/data1/lsj/new_spm_supervised/fseq"
    # mkdir -p $raw $bpe $fseq
    # shard=10
    # for i in `seq 1 $shard`; do
    #     mkdir -p $fseq/shard-$i
    # done
    # train
    #'de' 'es' 'fi' 'hi' 'ru' 'zh'
    # 'deu' 'spa' 'fin' 'hin' 'rus' 'zho' 'afr' 'sqi' 'eus' 'ben'
    # 'bul' 'cat' 'dan' 'glg' 'heb' 'hun' 'isl' 'lav' 'lit'
    # 'mkd' 'msa' 'nor' 'fas' 'por' 'slv' 'swe' 'tha' 'ukr';
    # 'hbs' 'ell' 'epo'
    for src in 'gu' "si" "ne"; do
        # if [ "$src" \> "en" ]; then
        #     tgt=$src
        #     src="en"
        # else
        #     tgt="en"
        # fi

        tgt="en"

        #f_src="train.$src-$tgt.$src"
        #f_tgt="train.$src-$tgt.$tgt"


        # preprocessing
        # if [ ! -f "$raw/$f_src.norm" ]; then
        #     preprocess_dataset $raw/$f_src $raw/$f_src.norm $src
        #     preprocess_dataset $raw/$f_tgt $raw/$f_tgt.norm $tgt
        # fi
        # if [ ! -f "$bpe/$f_src" ]; then
        #     python scripts/tools/spm_encode.py --model $WORKLOC/models/xlmr.large/sentencepiece.bpe.model \
        #         --inputs $raw/$src/$f_src $raw/$src/$f_tgt --outputs $bpe/$f_src $bpe/$f_tgt
        # fi
        # if [ ! -f "$fseq/train.$src-$tgt.bin" ]; then
        #     python fairseq_cli/preprocess.py -s $src -t $tgt --dataset-impl mmap \
        #                 --workers 12 --destdir $fseq  \
        #                 --trainpref $bpe/train.$src-$tgt \
        #                 --srcdict  $WORKLOC/models/xlmr.large/dict.txt \
        #                 --tgtdict $WORKLOC/models/xlmr.large/dict.txt
        # fi
        # split file into 10 part
        # if [ ! -f "$fseq/shard-1/train.$src-$tgt.$src" ]; then
        #     tlines=`awk 'END{print NR}' $bpe/$f_src`
        #     plines=`expr $tlines / $shard + 1`

        #     split -l $plines $bpe/$f_src "$bpe/$f_src.split."
        #     cnt=1
        #     for file in `ls $bpe/$f_src.split.*`
        #     do
        #         mv $file $fseq/shard-$cnt/train.$src-$tgt.$src
        #         cnt=`expr $cnt + 1`
        #     done

        #     split -l $plines $bpe/$f_tgt "$bpe/$f_tgt.split."
        #     cnt=1
        #     for file in `ls $bpe/$f_tgt.split.*`
        #     do
        #         mv $file $fseq/shard-$cnt/train.$src-$tgt.$tgt
        #         cnt=`expr $cnt + 1`
        #     done
        # fi
        # for i in `seq 1 $shard`; do
        #     if [ ! -f "$fseq/shard-$i/train.$src-$tgt.$src.bin" ]; then
        #         python fairseq_cli/preprocess.py -s $src -t $tgt --dataset-impl lazy \
        #             --workers 24 --destdir $fseq/shard-$i  \
        #             --trainpref $fseq/shard-$i/train.$src-$tgt \
        #             --srcdict  $WORKLOC/models/xlmr.large/dict.txt \
        #             --tgtdict $WORKLOC/models/xlmr.large/dict.txt
        #     fi
        # done



        # valid
        #valid_src="valid.$src-$tgt.$src"
        #valid_tgt="valid.$src-$tgt.$tgt"

        # if [ ! -f "$bpe/$valid_src" ]; then
        #     python scripts/tools/spm_encode.py --model $WORKLOC/models/xlmr.large/sentencepiece.bpe.model  \
        #         --inputs $raw/$src/$valid_src $raw/$src/$valid_tgt --outputs $bpe/$valid_src $bpe/$valid_tgt
        # fi

        # if [ ! -f "$fseq/valid.$src-$tgt.$src.bin" ]; then
        #     python fairseq_cli/preprocess.py -s $src -t $tgt --dataset-impl mmap \
        #         --workers 12 --destdir $fseq  \
        #         --validpref $bpe/valid.$src-$tgt \
        #         --srcdict  $WORKLOC/models/xlmr.large/dict.txt \
        #         --tgtdict $WORKLOC/models/xlmr.large/dict.txt
        # fi
        
        # test
        test_src="test.$src-$tgt.$src"
        test_tgt="test.$src-$tgt.$tgt"

        # if [ ! -f "$raw/$src/$test_src.norm" ]; then
        #     preprocess_dataset $raw/$src/$test_src $raw/$src/$test_src.norm $src
        #     preprocess_dataset $raw/$src/$test_tgt $raw/$src/$test_tgt.norm $tgt
        # fi

        
        # if [ ! -f "$bpe/$test_src" ]; then
        #     python scripts/tools/spm_encode.py --model /data/lsj/nfs/specific_mono/specific.model  \
        #         --inputs $raw/$src/$test_src.norm   --outputs $bpe/$test_src 

        #     python scripts/tools/spm_encode.py --model $WORKLOC/models/xlmr.large/sentencepiece.bpe.model  \
        #         --inputs $raw/$src/$test_tgt.norm  --outputs $bpe/$test_tgt
        
        # fi

        if [ ! -f "$fseq/test.$src-$tgt.$src.bin" ]; then
            python fairseq_cli/preprocess.py -s $src -t $tgt --dataset-impl mmap \
                --workers 12 --destdir $fseq  \
                --testpref $bpe/test.$src-$tgt \
                --srcdict  $WORKLOC/models/xlmr.large/dict.txt \
                --tgtdict $WORKLOC/models/xlmr.large/dict.txt
        fi

    done 

    # copy valid and test to every shard dir
    # for i in `seq 1 $shard`; do
    #     cp $fseq/*bin $fseq/shard-$i/
    #     cp $fseq/*idx $fseq/shard-$i/
    # done


}


export CUDA_VISIBLE_DEVICES=0
export WORKLOC=/data/lsj/sixt/sixtp

## First download the parallel corpora from urls in the appendix, put them in the $WORKLOC/raw path. All texts are supposed to be detokenized before running this script. 
## The dataset raw files are named with {train,valid,test}.{$src-en}.{$src,en}, e.g, train.de-en.de
## Assume the official XLM-R large model are stored in $WORKLOC/models/xlmrL_base 

#preprocess_datasets
binarize_fairseq_dataset