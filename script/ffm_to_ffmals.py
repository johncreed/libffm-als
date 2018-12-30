#! /usr/bin/python3

idx_cnt = {}
idx_map = {}

def convert_idx(field, idx, val):
    key = tuple([field, idx])
    if key not in idx_map:
        if field in idx_cnt:
            idx_cnt[field] += 1
            idx_map[key] = idx_cnt[field]
        else:
            idx_cnt[field] = 0
            idx_map[key] = idx_cnt[field]
    return idx_map[key]

def convert_line(line):
    toks  = line.strip().split()
    label = toks[0]
    res_list = [label]
    for tk in toks[1:]:
        tk_toks = tk.strip().split(":")
        field = tk_toks[0]
        idx = tk_toks[1]
        val = tk_toks[2]
        idx_cvt = convert_idx(field, idx, val)
        res_list.append("{}:{}:{}".format(field, idx_cvt, val))
    return " ".join(res_list) + "\n"

def sort_dict_and_print(src_dict):
    a = list(src_dict.items())
    print(sorted(a, key = lambda tup: int(tup[0])))

def convert(filename):
    rf = open(filename, 'r')
    of = open(filename+".cvt", 'w')
    for line in rf:
        line_cvt = convert_line(line)
        of.write(line_cvt)
    sort_dict_and_print(idx_cnt)

if __name__ == '__main__':
    convert("avazu-app.tr.ffm")
    convert("avazu-app.te.ffm")

