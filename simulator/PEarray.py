from PE import PE

class PE_array(object):
    def __init__(self, PE_size = (12,14)) -> None:
        self.PEs = [[PE() for i in range(PE_size[1])] for j in range(PE_size[0])]