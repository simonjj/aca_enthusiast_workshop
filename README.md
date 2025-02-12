[![Open in Dev Containers](https://img.shields.io/static/v1?label=Dev%20Containers&message=Open&color=blue)](https://vscode.dev/redirect?url=vscode://ms-vscode-remote.remote-containers/cloneInVolume?url=https://github.com/bmoussaud/aca_enthusiast_workshop)
# ACA Workshop

## Abstract 

We’ll dissect Azure Container Apps best practices for infrastructure as code, refine your development process, and unravel the complexities of networking architecture. Get hands-on with advanced troubleshooting and debugging techniques that only the pros know. This is your chance to elevate your ACA game and connect directly with the masterminds behind the platform.


## General Flow and Time Allocation

Intro (5 min)

Markitecture Overview (~10 min)
- Setup and creation
- How does ACA map to AKS
- Networking

General Problem Areas: (15-20 min)
- Identity Issues (chicken & egg issue around registry pull)
  - Follow-up Bicep deploy is impossible due to C&E MI issue
  - Fix: Switch to user-assigned identity or switch to env-level system-assigned
- Health Probes (settings, best defaults, what does it look like when they get misconfigured)
  - Error: App takes too long to start listening and hence never launches
  - Fix: Many, fix the probe
- Scaling (CPU/Memory custom scalers, MI + scaling)
  - Error: App scales on SB and misconfigure a few thing (identity)
- Networking (basics (BYO Vnet vs. managed), PE, dispel myths)
  - Error: Port blocking on custom Vnet port 80 ?
  - Setup PE + App and then manually finish by hooking AFD to it by following: https://learn.microsoft.com/en-us/azure/container-apps/how-to-integrate-with-azure-front-door


Hands On Lab (25-30min)


Next Steps:
- Figure out specific scenarios in each problem section
- Get engineering to participate
