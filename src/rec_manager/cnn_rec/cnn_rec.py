from ..rec_interface import RecInterface
from .cnn import load_model
from .dataset_build import MinihackDataset
from ...utils.device import get_device
import numpy as np
from PIL import Image
from torchvision.transforms import ToTensor

tile_size = (16, 16)

class VisualRec(RecInterface):
    def __init__(self, conf:dict):
        self.conf = conf
        device_str = self.conf.get('device', 'auto')
        self.device = get_device(device_str)
        self.model = load_model(self.conf['vision_config']['cnn_config']['num_classes'], self.device)
        self.to_tensor = ToTensor()

    def recognize(self, obs:np.ndarray) -> np.ndarray:
        MinihackDataset.update(img=obs)
        v, h, _ = obs.shape
        v_times, h_times = v//tile_size[0], h//tile_size[1]
        rec = []
        for i in range(v_times):
            rec_list = []
            for j in range(h_times):
                tile = obs[i*tile_size[0]:(i+1)*tile_size[0], j*tile_size[1]:(j+1)*tile_size[1]]
                # 在使用tile输入模型前进行转换
                tile = Image.fromarray(tile)
                tile_tensor = self.to_tensor(tile)
                tile_tensor = tile_tensor.unsqueeze(0).to(self.device)
                tile_rec = self.model(tile_tensor)
                tile_rec = tile_rec.squeeze(0)
                tile_rec = tile_rec.argmax(dim=0)
                rec_list.append(tile_rec.cpu().detach().numpy())
            rec.append(rec_list)
        return np.array(rec)