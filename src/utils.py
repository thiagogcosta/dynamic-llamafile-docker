import os
from pathlib import Path
from typing import List

import yaml

from src.logger import Logger

# ----------
# DESC: config the Logger
logger = Logger().get_logger()
# ----------


def _convert_values_to_strings(*, configs_list: List[dict]) -> List[dict]:
    return [{k: str(v) for k, v in config.items()} for config in configs_list]


def get_configs(*, configs_type: str) -> List[dict]:
    dir_path = os.path.dirname(os.path.realpath(__file__))
    configs_path = Path(dir_path) / 'resources' / f'{configs_type}.yaml'

    configs_list = None
    try:
        with open(configs_path, 'r') as file:
            configs_list = _convert_values_to_strings(configs_list=yaml.safe_load(file))
    except FileNotFoundError:
        logger.info(f"Error: The configuration file '{configs_path}' was not found.")
        raise
    except yaml.YAMLError as e:
        logger.info(f'Error: We got an error when parsing this YAML file: {e}')
        raise
    return configs_list
