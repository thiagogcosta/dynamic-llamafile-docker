import os
from pathlib import Path
from urllib.error import HTTPError, URLError

import wget

from src.logger import Logger
from src.templates.dataclass import Llamafile
from src.templates.downloader import Downloader

# ----------
# DESC: config the Logger
logger = Logger().get_logger()
# ----------


class LLamafileDownloader(Downloader):
    def config(self, *, llamafile_default: dict) -> dict:
        llamafile_config_list = [Llamafile(**config) for config in self._configs]

        filtered_llamafile = [
            llamafile_config
            for llamafile_config in llamafile_config_list
            if llamafile_default['version'] == llamafile_config.version
        ]

        if len(filtered_llamafile) == 1:
            return filtered_llamafile[0]
        else:
            raise Exception(
                'Error: Invalid filtered LLamafile config, please, check the configs file'
            )

    def download(self, *, filtered_llamafile: str) -> None:
        url_llamafile = filtered_llamafile.link
        llamafile_path = Path('/tmp/llamafile.zip')

        if llamafile_path.is_file():
            logger.info(f'Success: File already exists at: {llamafile_path}')

        try:
            filename = wget.download(url_llamafile, out=str(llamafile_path))
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
        llamafile_default = {
            'version': os.getenv('LLAMAFILE_VERSION', ''),
        }

        logger.info(f'llamafile_default: {llamafile_default}')

        filtered_llamafile = self.config(llamafile_default=llamafile_default)
        self.download(filtered_llamafile=filtered_llamafile)
