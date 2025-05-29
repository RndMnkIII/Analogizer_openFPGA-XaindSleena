# Script TCL para usar como POST_FLOW_SCRIPT_FILE
# Añadir al archivo QSF del proyecto: set_global_assignment -name POST_FLOW_SCRIPT_FILE "invertir_rbf_post.tcl"
# 1. Obtener el nombre base del proyecto y archivo .sof
set project_name [get_project_name]
set sof_file "${project_name}.sof"
set rbf_file "${project_name}.rbf"
set rbf_invertido "${project_name}.rbf_r"

# 2. Convertir .sof → .rbf (modo raw binary)
puts "Convirtiendo $sof_file a $rbf_file..."
if {[file exists $sof_file]} {
    catch {exec quartus_cpf -c $sof_file $rbf_file} result
    puts "Resultado de quartus_cpf: $result"
} else {
    puts "ERROR: No se encuentra $sof_file"
    exit 1
}

# 3. Función para invertir bits de un byte
proc reverse_byte {byte} {
    set bin [format %08b $byte]
    set rev [reverseBits $bin]
    return [expr 0b$rev]
}

# 4. Invertir bits del archivo .rbf
puts "Invirtiendo bits de $rbf_file → $rbf_invertido..."
set fin [open $rbf_file "rb"]
fconfigure $fin -translation binary
set fout [open $rbf_invertido "wb"]
fconfigure $fout -translation binary

while {[eof $fin] == 0} {
    binary scan [read $fin 1] c byte
    if {[eof $fin]} break
    if {$byte < 0} { set byte [expr $byte + 256] }

    set b_inv [reverse_byte $byte]
    puts -nonewline $fout [binary format c $b_inv]
}

close $fin
close $fout
puts "Hecho: archivo generado $rbf_invertido"
