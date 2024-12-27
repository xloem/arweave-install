import urllib.parse
import openai as llm

class Inference:
    def __init__(self, service):
        url, key, model = service_str_to_url_key_model(service)
        self.llm = llm.OpenAI(base_url = url)
        self.llm.api_key = key
        self.model = model
    def generate(self, prompt, *files, system_prompt_prefix = 'Below are contextual datafiles.\n', file_prefix = '\n# {filename}\n', file_suffix = '', system_prompt_suffix = '', **kwparams):
        system_prompt = system_prompt_prefix
        for filename in files:
            with open(filename, 'rt') as fileobj:
                filecontent = fileobj.read()
            system_prompt += file_prefix.format(filename=filename) + filecontent + file_suffix.format(filename=filename)
        system_prompt += system_prompt_suffix
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

def service_str_to_url_key_model(service):
    spliturl = urllib.parse.urlsplit(service)
    model = spliturl.username
    key = spliturl.password
    scheme, netloc, path, query, fragment = spliturl
    netloc = netloc.split('@',1)[1]
    url = urllib.parse.urlunsplit([scheme, netloc, path, query, fragment])
    return url, key, model

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--files', action='append', nargs='*', required=True)
    parser.add_argument('--prompt', required=True)
    parser.add_argument('--service', default='https://Meta-Llama-3.1-405B-Instruct:f47ef722-8eea-4f95-8d57-02027bdc9401@api.sambanova.ai/v1')
    parser.add_argument('--temperature', default=0)
    parser.add_argument('--max-tokens', default=1024)
    args = parser.parse_args()
    args.files = sum(args.files,[])
    inference = Inference(args.service)
    inference.generate(args.prompt, *args.files, temperature=args.temperature, max_tokens=int(args.max_tokens))
