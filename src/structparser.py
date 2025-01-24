from pycparser import c_ast, parse_file
import subprocess
import sys

    

def generate_struct_dumper(struct_def: c_ast.Struct, target_name: str):
    
    out_lines = []

    
        
    out_lines.append("#include <stdio.h>")
    out_lines.append("#include <vulkan/vulkan.h>")
    out_lines.append("#define membersize(s, m) ((unsigned int)(sizeof(((s*)0)->m)))")
    out_lines.append("int main(void) {")
    
    out_lines.append(f'    printf("{target_name}: 0x%.2X\\n", (unsigned int)sizeof({target_name}));')
    out_lines.append('    printf("--------------------------------------------\\n");')
    fields = []
    max_field_len = 0
    for decl in struct_def.decls:
        decl: c_ast.Decl
        if not isinstance(decl.type, (c_ast.TypeDecl, c_ast.PtrDecl)):
            raise ValueError(f"Unsupported member type: {decl}")
        field_name = decl.name
        if len(field_name) > max_field_len:
            max_field_len = len(field_name)
        fields.append(field_name)
        
    
    for field in fields:
        padded_field = field.ljust(max_field_len)
        out_lines.append(f'    printf("{target_name}.{padded_field}: 0x%.2X  0x%.2X  %s\\n", '
                f'(unsigned int)__builtin_offsetof({target_name}, {field}), '
                f'membersize({target_name}, {field}), '
                f'membersize({target_name}, {field}) == 0x08 ? "QWORD" : membersize({target_name}, {field}) == 0x04 ? "DWORD" : "-");'
            )
    out_lines.append("    return 0;")
    out_lines.append("}")

    return '\n'.join(out_lines)
        
        

def compile_clang(input_str, args):
    command = ('clang', '-xc', *args, '-')
    subprocess.run(command, input=input_str, encoding='utf-8')

def main():

    if len(sys.argv) < 2:
        print(f"usage: python {sys.argv[0]} <structname>")
        return

    target_struct_name = sys.argv[1]

    ast: c_ast.FileAST = parse_file("./src/vkpreprocessed2.h")

    target_struct: c_ast.Struct = None

    for ext in ast.ext:
        if isinstance(ext, c_ast.Typedef) and ext.name == target_struct_name:
            target_struct = ext.type.type
            break            
    

    clang_str = generate_struct_dumper(target_struct, target_struct_name)
    outfile = "structdump.exe"
    compile_clang(clang_str, [r'-IC:\VulkanSDK\1.3.296.0\Include', '-o', outfile])
    subprocess.run([f'.\\{outfile}'])


            

    
if __name__ == "__main__":
    main()