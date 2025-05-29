import sys

opcode_labels = {
    0x3E: "START OF MIF",
    0x3F: "END OF MIF",
    0x04: "M COUNTER",
    0x03: "N COUNTER",
    0x05: "C COUNTER",
    0x08: "BANDWIDTH",
    0x09: "CHARGE PUMP",
    0x02: "START RECONFIG"
}

def clean_bin(word):
    # Eliminar comentarios y caracteres extra
    return word.split(';')[0].strip()

def parse_mif(filename):
    with open(filename, 'r') as f:
        lines = [line.strip() for line in f if ':' in line and not line.strip().startswith('--')]

    instructions = []
    i = 0
    while i < len(lines):
        line = lines[i]
        _, data = line.split(':')
        word = clean_bin(data)

        # Detect opcode (lowest 6 bits)
        try:
            opcode_val = int(word, 2) & 0x3F
        except ValueError:
            i += 1
            continue

        label = opcode_labels.get(opcode_val, None)

        if opcode_val in [0x3E, 0x3F]:  # SOM / EOM
            instructions.append((word, None, label))
            i += 1
        else:
            if i + 1 < len(lines):
                _, data2 = lines[i + 1].split(':')
                value = clean_bin(data2)
                instructions.append((word, value, label))
                i += 2
            else:
                break
    return instructions

def generate_verilog_array(instructions, name):
    result = []
    result.append(f"localparam int {name.upper()}_LEN = {len(instructions) * 2};")
    result.append(f"logic [31:0] {name} [0:{len(instructions) * 2 - 1}] = '{{")
    for idx, (opcode, value, label) in enumerate(instructions):
        comment = f" // {label}" if label else ""
        if value:
            result.append(f"  'h{int(opcode, 2):X}, 'h{int(value, 2):X},{comment}")
        else:
            result.append(f"  'h{int(opcode, 2):X},{comment}")
    result.append("};")
    return "\n".join(result)

def main():
    if len(sys.argv) != 3:
        print("Uso: python parse_streaming_mif_labeled.py archivo.mif nombre_array")
        sys.exit(1)

    mif_file = sys.argv[1]
    array_name = sys.argv[2]

    instructions = parse_mif(mif_file)
    output = generate_verilog_array(instructions, array_name)
    print(output)

if __name__ == "__main__":
    main()
