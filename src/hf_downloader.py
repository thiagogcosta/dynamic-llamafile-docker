import os
from pathlib import Path
from urllib.error import HTTPError, URLError

import wget

from src.logger import Logger
from src.templates.dataclass import HFModel
from src.templates.downloader import Downloader

# ----------
# DESC: config the Logger
logger = Logger().get_logger()
# ----------


class HFDownloader(Downloader):
    def config(self, *, model_default: dict) -> dict:
        hf_models_list = [HFModel(**config) for config in self._configs]

        filtered_hf_model = [
            hf_model
            for hf_model in hf_models_list
            if (
                model_default['name'] == hf_model.name
                and model_default['version'] == hf_model.version
                and model_default['qtd_params'] == hf_model.qtd_params
                and model_default['quant_method'] == hf_model.quant_method
            )
        ]

        if len(filtered_hf_model) == 1:
            return filtered_hf_model[0]
        else:
            raise Exception(
                'Error: Invalid filtered Hugging Face model, please, check the configs file'
            )

    def download(self, *, filtered_hf_model: str) -> None:
        hf_model_url = filtered_hf_model.link
        model_path = Path('/tmp/model.gguf')

        if model_path.is_file():
            logger.info(f'Success: File already exists at: {model_path}')

        try:
            filename = wget.download(hf_model_url, out=str(model_path))
            logger.info(f'Success: Downloaded file saved as: {filename}')

        except HTTPError as e:
            logger.error(f'Error: HTTP error occurred: {e.code} - {e.reason}')
            raise
        except URLError as e:
            logger.error(f'Error: URL error occurred: {e.reason}')
            raise
        except FileNotFoundError:
            logger.error('Error: The specified output directory does not exist.')
            raise
        except PermissionError:
            logger.error(
                'Error: Permission denied. Cannot write to the specified directory.'
            )
            raise
        except OSError as e:
            logger.error(f'Error: OS error occurred: {e}')
            raise
        except Exception as e:
            logger.error(f'Error: An unexpected error occurred: {e}')
            raise

    def execute(self):
        model_default = {
            'name': os.getenv('MODEL_NAME', ''),
            'version': os.getenv('MODEL_VERSION', ''),
            'qtd_params': os.getenv('MODEL_QTD_PARAMS', ''),
            'quant_method': os.getenv('MODEL_QUANT_METHOD', ''),
        }

        logger.info(f'model_default: {model_default}')

        filtered_hf_model = self.config(model_default=model_default)
        self.download(filtered_hf_model=filtered_hf_model)
