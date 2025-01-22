import os

from src.llamafile_downloader import LLamafileDownloader
from src.logger import Logger

# ----------
# DESC: config the Logger
logger = Logger().get_logger()
# ----------

llamafile_default = {
    'version': os.getenv('LLAMAFILE_VERSION', ''),
    'folder_name_reference_file': '/tmp/llamafile_folder_name.txt',
}

logger.info('-' * 10)
logger.info(f'{llamafile_default}')
logger.info('-' * 10)

downloader = LLamafileDownloader(configs_type='llamafile_configs')

llamafile_config = downloader.config(llamafile_default=llamafile_default)

llamafile_folder_name = open(llamafile_default.get('folder_name_reference_file'), 'w')
llamafile_folder_name.write(f'{llamafile_config.folder_name}')
llamafile_folder_name.close()
