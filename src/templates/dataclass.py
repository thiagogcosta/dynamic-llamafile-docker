from pydantic import BaseModel, Field


class BaseConfig(BaseModel):
    version: str = Field(..., min_length=3, max_length=11)
    link: str = Field(..., min_length=10, max_length=150)


class Llamafile(BaseConfig):
    folder_name: str = Field(..., min_length=9, max_length=100)


class HFModel(BaseConfig):
    name: str = Field(..., min_length=3, max_length=20)
    qtd_params: str = Field(..., min_length=1, max_length=5)
    quant_method: str = Field(..., min_length=3, max_length=15)
