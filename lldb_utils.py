import lldb

def rope_index_summary(valobj, internal_dict):
    position = valobj.GetChildMemberWithName('i').GetChildMemberWithName('position').GetValue()
    lend = valobj.GetChildMemberWithName('lineViewEnd')

    summary = f'{position}[utf8]'
    if read_bool(lend):
        summary += '+lend'

    return summary

def read_bool(valobj):
    return valobj.GetChildMemberWithName('_value').GetValueAsUnsigned() == 1

def get_type(name):
    target = lldb.debugger.GetSelectedTarget()
    return target.FindFirstType(name)

