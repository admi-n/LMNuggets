from eth_hash.auto import keccak

def hash_phone_number(phone_number: str) -> bytes:
    """
    对买家的手机号进行 Keccak 哈希加密，并返回 bytes32 格式
    """
    input_data = phone_number
    input_bytes = input_data.encode('utf-8')
    hashed = keccak(input_bytes)
    # 只取前32字节
    return hashed[:32]  # 返回前32字节（bytes32）

def hash_address(address: str) -> bytes:
    """
    对买家的地址进行 Keccak 哈希加密，并返回 bytes32 格式
    """
    input_data = address
    input_bytes = input_data.encode('utf-8')
    hashed = keccak(input_bytes)
    # 只取前32字节
    return hashed[:32]  # 返回前32字节（bytes32）

if __name__ == "__main__":
    # 输入手机号和地址
    phone_number = "15555555555"
    address = "北京市朝阳区"
    
    # 分别对手机号和地址进行哈希
    buyer_phone_hash = hash_phone_number(phone_number)
    buyer_address_hash = hash_address(address)
    
    # 输出哈希结果
    print(f"hash_phone_number: 0x{buyer_phone_hash.hex()}")
    print(f"hash_address: 0x{buyer_address_hash.hex()}")
