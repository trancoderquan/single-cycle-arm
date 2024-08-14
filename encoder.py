import re
f = open("memfile.txt","a")

def tobinary(n,not_b): #number to binary
    return f'{not_b:0{n}b}'

def Conditional (Cond): #Condition to binary
    S_b=0
    if Cond == "EQ":
        Cond_b = "0000"
    elif Cond == "NE":
        Cond_b = "0001"
    elif Cond == "CS" or Cond == "HS":
        Cond_b = "0010"
    elif Cond == "CC" or Cond == "LO":
        Cond_b = "0011"
    elif Cond == "MI":
        Cond_b = "0100"
    elif Cond == "PL":
        Cond_b = "0101"
    elif Cond == "VS":
        Cond_b = "0110"
    elif Cond == "VC":
        Cond_b = "0111"
    elif Cond == "HI":
        Cond_b = "1000"
    elif Cond == "LS":
        Cond_b = "1001"
    elif Cond == "GE":
        Cond_b = "1010"
    elif Cond == "LT":
        Cond_b = "1011"
    elif Cond == "GT":
        Cond_b = "1100"
    elif Cond == "LE":
        Cond_b = "1101"
    elif Cond == "S":
        Cond_b = "1110"
        S_b = "1"
    else:
        Cond_b = "1110"

    return [Cond_b, S_b]
def Operation (Op):
    if Op =="ADD" or Op == "SUB": #Data processing
       return "00"
    elif Op == "LDR" or Op == "STR": #Storage 
        return "01"
    
def Immediate (I, Op_b): #Immediate handling
    if I == '#' and (Op_b == "00"):
        return 1
    elif I =="R" and (Op_b == "00"):
        return 0
    elif I == '#' and (Op_b == "01"):
        return 0
    elif I == 'R' and (Op_b == "01"):
        return 1
    
while True:
    Instr= input ("Instruction:")
    spl_Instr = re.split ("\s",Instr)
    Op = spl_Instr[0][0:3]#Op field
    Cond = spl_Instr[0].replace(Op,'')#Cond Field
    [Rd,Rn,Rm] = spl_Instr[1:4] #Split fields: destination, operands 1, operands 2
    #Conditional flags
    [Cond_b, S_b] = Conditional(Cond)
    #Operation
    Op_b = Operation(Op) #Data or storage
    #Constants
    I_b = Immediate (Rm[0:1], Cond_b) 
    print (Cond_b, S_b)
    if Op =="ADD":
        if Rm[0:1] == 'R' :
            encoded = "111000001000"+'{0:04b}'.format(int(Rn[1:2]))+'{0:04b}'.format(int(Rd[1:2]))+"00000000"+'{0:04b}'.format(int(Rm[1:3]))
        if Rm[0:1] == '#' :
            encoded = "111000101000"+'{0:04b}'.format(int(Rn[1:2]))+'{0:04b}'.format(int(Rd[1:2]))+"0000"+'{0:08b}'.format(int(Rm[1:2]))
    elif Op =="SUB":
        if Rm[0:1] == 'R' :
            encoded = "111000000100"+'{0:04b}'.format(int(Rn[1:2]))+'{0:04b}'.format(int(Rd[1:2]))+"00000000"+'{0:04b}'.format(int(Rm[1:3]))
        if Rm[0:1] == '#' :
            encoded = "111000100100"+'{0:04b}'.format(int(Rn[1:2]))+'{0:04b}'.format(int(Rd[1:2]))+"0000"+'{0:08b}'.format(int(Rm[1:2]))

    f.writelines ([encoded,"\n"])
    f.flush()
    
    
    

