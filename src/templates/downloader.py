from src.templates.singleton import Singleton
from src.utils import get_configs


class Downloader(Singleton):
    def __init__(self, configs_type: str) -> None:
        self._configs = get_configs(configs_type=configs_type)

    def config(self):
        raise NotImplementedError()

    def download(self):
        raise NotImplementedError()

    def execute(self):
        raise NotImplementedError()
