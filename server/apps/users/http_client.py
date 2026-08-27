import json
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


class ExternalHttpError(Exception):
    def __init__(self, message: str, *, status_code: int | None = None, payload: dict | None = None):
        super().__init__(message)
        self.status_code = status_code
        self.payload = payload or {}


def request_json(
    url: str,
    *,
    method: str = "POST",
    json_body: dict | None = None,
    form_body: dict | None = None,
    query: dict | None = None,
    headers: dict[str, str] | None = None,
    timeout: int = 15,
) -> dict:
    request_url = url
    if query:
        request_url = f"{url}?{urlencode(query)}"

    body = None
    request_headers = {"Accept": "application/json", **(headers or {})}
    if json_body is not None:
        body = json.dumps(json_body).encode("utf-8")
        request_headers["Content-Type"] = "application/json"
    elif form_body is not None:
        body = urlencode(form_body).encode("utf-8")
        request_headers["Content-Type"] = "application/x-www-form-urlencoded"

    request = Request(request_url, data=body, headers=request_headers, method=method.upper())
    try:
        with urlopen(request, timeout=timeout) as response:
            raw = response.read().decode("utf-8")
            status_code = getattr(response, "status", 200)
    except HTTPError as error:
        raw = error.read().decode("utf-8", errors="replace")
        payload = _parse_json_object(raw)
        message = _extract_error_message(payload) or f"HTTP {error.code}"
        raise ExternalHttpError(message, status_code=error.code, payload=payload) from error
    except URLError as error:
        raise ExternalHttpError("Сервис временно недоступен") from error

    payload = _parse_json_object(raw)
    if status_code >= 400:
        raise ExternalHttpError(
            _extract_error_message(payload) or f"HTTP {status_code}",
            status_code=status_code,
            payload=payload,
        )
    return payload


def _parse_json_object(raw: str) -> dict:
    if not raw.strip():
        return {}
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def _extract_error_message(payload: dict) -> str:
    for key in ("error_message", "message", "detail", "error"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""
