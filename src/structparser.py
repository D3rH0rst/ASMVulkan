from pycparser import c_parser, c_ast, parse_file
import ctypes



struct_name = "VkGraphicsPipelineCreateInfo"


def get_type_size(member_type: c_ast.TypeDecl):
    print(member_type)
    

def define_ctypes_struct(struct_def: c_ast.Struct):
    for decl in struct_def.decls:
        decl: c_ast.Decl
        if not isinstance(decl.type, (c_ast.TypeDecl, c_ast.PtrDecl)):
            raise ValueError(f"Unsupported member type: {decl}")
        
        field_name = decl.name
        field_type = None
        field_size = 0
        field_offset = 0

        is_ptr =  isinstance(decl.type, c_ast.PtrDecl)

        if is_ptr:

            field_type = decl.type.type.type.names[0] + "*"
            field_size = 8
        else:
            field_type = decl.type.type.names[0]
            field_size = get_type_size(decl.type)
        
        #print(f"{field_type} {field_name} size: 0x{hex(field_size)}, offset: 0x{hex(field_offset)}")
        
        

        

        

def main():
    ast: c_ast.FileAST = parse_file("./src/vkpreprocessed2.h")

    target_struct: c_ast.Struct = None

    for ext in ast.ext:
        if isinstance(ext, c_ast.Typedef) and ext.name == struct_name:
            target_struct = ext.type.type
            break
        
    cstruct = define_ctypes_struct(target_struct)



            

    
if __name__ == "__main__":
    main()