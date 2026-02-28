from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file='.env', env_file_encoding='utf-8', extra='ignore')

    app_url: str = 'http://localhost:8005'
    database_url: str = 'postgresql://postgres:postgres@localhost:5432/freebyte_app'

    price_per_gb: int = 1550
    price_per_day: int = 500

    zarinpal_merchent_id: str = ''
    iran_callback_url: str | None = None

    cryptomus_callback_url: str | None = None
    cryptomus_api_key: str = ''
    cryptomus_merchant_id: str = ''

    telegram_bot_token: str = ''
    telegram_thread_id: int = 0
    admin_chat_ids: str = '-1002115809340'

    marzban_username: str = ''
    marzban_password: str = ''

    secret_key: str = Field(default='change_me_access_secret')
    refresh_secret_key: str = Field(default='change_me_refresh_secret')
    algorithm: str = 'HS256'

    @property
    def computed_iran_callback_url(self) -> str:
        return self.iran_callback_url or f'{self.app_url}/iran_recive_payment_result/'

    @property
    def computed_cryptomus_callback_url(self) -> str:
        return self.cryptomus_callback_url or f'{self.app_url}/crypto_recive_payment_result'

    @property
    def admin_chat_ids_list(self) -> list[int]:
        result: list[int] = []
        for item in self.admin_chat_ids.split(','):
            item = item.strip()
            if not item:
                continue
            try:
                result.append(int(item))
            except ValueError:
                continue
        return result or [-1002115809340]


settings = Settings()
