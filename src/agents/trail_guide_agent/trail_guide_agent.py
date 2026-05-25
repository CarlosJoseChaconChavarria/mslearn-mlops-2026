import argparse
import os
from pathlib import Path

from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from dotenv import load_dotenv


def main():
    load_dotenv()

    parser = argparse.ArgumentParser(description="Deploy a Trail Guide Agent version to Azure AI Foundry")
    parser.add_argument("--version", required=True, choices=["v1", "v2", "v3"], help="Agent version to deploy")
    args = parser.parse_args()

    prompt_file = Path(__file__).parent / "prompts" / f"{args.version}_instructions.txt"
    instructions = prompt_file.read_text(encoding="utf-8")

    endpoint = os.environ["AZURE_AI_PROJECT_ENDPOINT"]
    agent_name = os.environ.get("AGENT_NAME", "trail-guide")
    model_name = os.environ.get("MODEL_NAME", "gpt-4.1")

    client = AIProjectClient(endpoint=endpoint, credential=DefaultAzureCredential())

    agent = client.agents.create_agent(
        model=model_name,
        name=agent_name,
        instructions=instructions,
    )

    version_number = args.version.lstrip("v")
    print(f"Agent created (id: {agent.id}, name: {agent.name}, version: {version_number})")


if __name__ == "__main__":
    main()
