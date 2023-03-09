NUM_EXPERTS=4
max_tokens=3000
max_updates=50000
#DATA="/data/lsj/nfs/it_experiment/data/general_data/text_data/enfr"
DATA="/data/lsj/nfs/moe/moe_data"
SAVE="/data/lsj/nfs/moe/moe_model3"
lang_pairs="fi-en" #,es-en,fi-en,hi-en,ru-en,zh-en,en-de,en-es,en-fi,en-hi,en-ru,en-zh"
lang_dict="en,fi" #,es,fi,hi,ru,zh"
export CUDA_VISIBLE_DEVICES=0,1,2,3
python -m torch.distributed.launch --nproc_per_node=4 --master_addr="127.0.0.1" --master_port=12345 \
train.py $DATA \
  --ddp-backend fully_sharded --fp16 \
  --task translation_multi_simple_epoch \
  --langtoks-specs "main" \
  --langtoks "{\"main\":(\"src\", \"tgt\")}" \
  --sampling-method 'temperature' --sampling-temperature 5 \
  --langs ${lang_dict} --lang-pairs ${lang_pairs} \
  --enable-reservsed-directions-shared-datasets \
  --encoder-normalize-before --decoder-normalize-before \
  --arch transformer --share-all-embeddings \
  --encoder-layers 3 --decoder-layers 3 \
  --encoder-embed-dim 128 --encoder-ffn-embed-dim 256 \
  --max-source-positions 512 --max-target-positions 512 \
  --encoder-attention-heads 8 --decoder-attention-heads 8 \
  --moe-expert-count $NUM_EXPERTS --moe-freq 2 \
  --moe-gating-use-fp32 --moe-second-expert-policy all \
  --moe-normalize-expert-grad sqrt_world_size \
  --moe-eval-capacity-token-fraction -1.0 \
  --criterion moe_cross_entropy --moe-gate-loss-wt 0.1 --moe-gate-loss-combine-method sum \
  --optimizer adam --adam-betas '(0.9, 0.98)' --clip-norm 0.0 \
  --lr 0.0005 --lr-scheduler polynomial_decay --total-num-update $max_updates --max-update $max_updates \
  --dropout 0.2 --attention-dropout 0.2 \
  --max-tokens $max_tokens --update-freq 2 \
  --log-interval 1 \
  --save-interval-updates 10 --save-dir $SAVE --keep-interval-updates 1 \
  --dataset-impl "mmap" \
  --record-a2a-perf-stats \
  --use-moe-pad-mask \
  --moe-batch-prioritized-routing \
  --symlink-best-and-last-checkpoints \
  --enable-lang-ids --use-moe-lang-perception

# moe-eval-capacity-token-fraction # 设置为-1则在eval的时候也会使用training时候的capacity，即2*num_tokens/num_experts，这可能会导致capacity过小，丢失很多token, 使得很多token在moe layer的输出为0，即跳过moe
# --use-moe-pad-mask 不发送pad token，可能可以降低计算成本(全0行变多了)