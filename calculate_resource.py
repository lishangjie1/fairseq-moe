import math
"""
num_gpu 所有卡的数量
num_layer 模型层数(encoder + decoder)
d_model 模型维度
bsz 单卡上的max_token/wpb
model_size 模型总参数量
data_size 数据token总数
base_wps 根据dummy_mt计算的单卡wps
bdw 通信带宽(bit/s)

"""
def compute_time(num_gpu, num_layer, dmodel, bsz, model_size, data_size, base_wps, bdw, moe_freq):
    computation_time = bsz / base_wps
    global_bsz = bsz * num_gpu
    num_step = data_size / global_bsz
    all2all_forward = 2
    all2all_backward = 2
    fp16 = 16 # 16bit
    all2all_datasize = bsz * dmodel * fp16 * num_layer * all2all_forward * all2all_backward / moe_freq # top1gate
    scale_factor = math.sqrt(num_gpu) # 根据gshard，随着device数量D增加，all2all通信成本按sqrt(D)增加
    all_reduce_datasize = model_size*fp16
    communication_time = (all_reduce_datasize+all2all_datasize*scale_factor) / bdw
    print(f"computation time per step: {computation_time} s, communication time per step: {communication_time} s")
    print(f"all reduce time: {all_reduce_datasize/bdw} s, all2all time:{all2all_datasize*scale_factor/bdw} s")
    train_time_per_step = computation_time + communication_time
    train_time = train_time_per_step * num_step / (3600 * 24) # the number of day
    return train_time

def compute_bdw(num_gpu, num_layer, dmodel, bsz, model_size, data_size, train_time, base_wps, moe_freq):
    computation_time = bsz / base_wps
    global_bsz = bsz * num_gpu
    num_step = data_size / global_bsz
    train_time_per_step = train_time / num_step
    # print(train_time_per_step)
    communication_time = train_time_per_step - computation_time
    # print(communication_time)
    all2all_forward = 2
    all2all_backward = 2
    fp16 = 16 # 16bit
    all2all_datasize = bsz * dmodel * fp16 * num_layer * all2all_forward * all2all_backward / moe_freq
    scale_factor = math.sqrt(num_gpu) # 根据gshard，随着device数量D增加，all2all通信成本按sqrt(D)增加
    all_reduce_datasize = model_size * fp16
    bdw = (all_reduce_datasize + all2all_datasize * scale_factor) / communication_time
    return bdw


if __name__ == "__main__":
    
    num_gpu = 4*8 # 4台8卡a100
    num_layer = 48 # 24encoder - 24decoder
    moe_freq = 4 
    d_model = 2048
    bsz = 7500 # 单卡上的max_token/wpb
    model_size = 42.334e8 # 26.22共享参数，16.11e专家参数
    data_size = 3e11 # 70亿句*60token/句
    base_wps = 5000 # 实验测得wps
    bdw = 100e9 # 100Gbit/s
    days = compute_time(num_gpu, num_layer, d_model, bsz, model_size, data_size, base_wps, bdw, moe_freq)
    print(f"Training needs {days} days")
    #compute_bdw(20*8, 24, 4096, 4096, 6e9, 7e9*60, 3*30*24*3600, 2837)/1e9