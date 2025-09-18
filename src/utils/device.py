import torch
from loguru import logger

def get_device(device_str: str = 'auto'):
    """
    Get device (torch.device) from str or auto.
    - 'auto': cuda -> mps -> cpu.
    - 'cuda', 'cuda:0', 'cpu', 'mps', etc.: get device from str directly.
    """
    device = None
    if device_str == 'auto':
        if torch.cuda.is_available():
            device = torch.device("cuda")
            logger.info("Device automatically set to 'cuda'.")
        elif torch.backends.mps.is_available():
            device = torch.device("mps")
            logger.info("Device automatically set to 'mps'.")
        else:
            device = torch.device("cpu")
            logger.info("Device automatically set to 'cpu'.")
    else:
        try:
            device = torch.device(device_str)
            logger.info(f"Device set to '{device_str}' from config.")
        except Exception as e:
            logger.error(f"Invalid device '{device_str}' in config. Falling back to CPU. Error: {e}")
            device = torch.device("cpu")
    return device
