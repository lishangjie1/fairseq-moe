

bpe="/data/lsj/sixt/acl22-sixtp/bpe"
fseq="/data/lsj/nfs1/moe/moe_data"
dict=/data/lsj/sixt/acl22-sixtp/models/xlmr.large/dict.txt

tgt="en"
for src in "de" "es" ; do
python fairseq_cli/preprocess.py -s $src -t $tgt --dataset-impl mmap \
                --workers 12 --destdir $fseq  \
                --trainpref $bpe/train.$src-$tgt \
                --srcdict  $dict \
                --tgtdict  $dict

# python fairseq_cli/preprocess.py -s $src -t $tgt --dataset-impl mmap \
#                 --workers 12 --destdir $fseq  \
#                 --validpref $bpe/valid.$src-$tgt \
#                 --srcdict  $dict \
#                 --tgtdict  $dict

# python fairseq_cli/preprocess.py -s $src -t $tgt --dataset-impl mmap \
#                 --workers 12 --destdir $fseq  \
#                 --testpref $bpe/test.$src-$tgt \
#                 --srcdict  $dict \
#                 --tgtdict  $dict
done