import base64, urllib.parse, logging
import openai as llm

class Inference:
    def __init__(self, service):
        url, key, model = service_str_to_url_key_model(service)
        self.llm = llm.OpenAI(base_url = url, api_key = key)
        self.model = model
    def generate(self, prompt, *files, system_prompt_prefix = 'Below are contextual datafiles.\n', file_prefix = '\n# {filename}\n', file_suffix = '', system_prompt_suffix = '', **kwparams):
        system_prompt = system_prompt_prefix
        for filename in files:
            with open(filename, 'rt') as fileobj:
                filecontent = fileobj.read()
            system_prompt += file_prefix.format(filename=filename) + filecontent + file_suffix.format(filename=filename)
        system_prompt += system_prompt_suffix
        while True:
            try:
                response = self.llm.chat.completions.create(
                    model = self.model,
                    messages = [
                        dict(role='system', content=system_prompt),
                        dict(role='user', content=prompt),
                    ],
                    **kwparams,
                    stream = True,
                )
                doc = ''
                for update in response:
                    text = update.choices[0].delta.content
                    print(text, end='', flush=True)
                    doc += text
                return doc
            except llm.APIError as err:
                logging.warning(err.body)
                if err.body['code'] == 429:
                    logging.warning('trying again, this may take a long time')
                    continue
                raise

def service_str_to_url_key_model(service):
    spliturl = urllib.parse.urlsplit(service)
    key = spliturl.username or spliturl.password
    model = spliturl.fragment
    scheme, netloc, path, query, fragment = spliturl
    url = urllib.parse.urlunsplit([scheme, netloc.split('@',1)[1], path, query, ''])
    return url, key, model

SERVICE_SAMBANOVA_LLAMA31_405 = 'https://f47ef722-8eea-4f95-8d57-02027bdc9401@api.sambanova.ai/v1#Meta-Llama-3.1-405B-Instruct'
SERVICE_SAMBANOVA_LLAMA31_70 = 'https://f47ef722-8eea-4f95-8d57-02027bdc9401@api.sambanova.ai/v1#Meta-Llama-3.1-70B-Instruct'
SERVICE_SAMBANOVA_LLAMA33_70 = 'https://f47ef722-8eea-4f95-8d57-02027bdc9401@api.sambanova.ai/v1#Meta-Llama-3.3-70B-Instruct'
_OPENROUTER_API_KEY = base64.b64decode('c2stb3ItdjEtMTI3NzZiYmQwMmQ5MTE1OGQ0YzRiZjAwYjA3YmRkMDIyNTViZjY3YWRkYThjZWU3YmNlNTNlYmU4MDI4YTNjOA==').decode()
SERVICE_OPENROUTER_LLAMA31_405 = f'https://{_OPENROUTER_API_KEY}@openrouter.ai/api/v1#meta-llama/llama-3.1-405b-instruct:free'

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--files', action='append', nargs='*', required=True)
    parser.add_argument('--prompt', required=True)
    parser.add_argument('--service', default=SERVICE_SAMBANOVA_LLAMA31_70)
    parser.add_argument('--temperature', default=0)
    parser.add_argument('--max-tokens', default=1024)
    args = parser.parse_args()
    args.files = sum(args.files,[])
    inference = Inference(args.service)
    inference.generate(args.prompt, *args.files, temperature=args.temperature, max_tokens=int(args.max_tokens))
