# PetTranslator

PetTranslator is an Ashita v4 addon for Final Fantasy XI that simplifies pet command management for Beastmaster, Summoner, and Puppetmaster jobs by translating generic commands into job-specific pet abilities.

> **Note:**  
> This addon is designed for Ashita v4 and the [CatsEyeXI private server](https://www.catseyexi.com/).


## Features

- **Unified Commands:** Use simple `/pt` commands instead of remembering job-specific ability names
- **Smart Translation:** Automatically translates `go`, `stop`, and `bye` commands to the correct pet ability based on your current job
- **Level Awareness:** Respects level requirements for each pet ability
- **Flexible Targeting:** Support for custom targeting on attack commands (`<t>`, `<st>`, `<bt>`, etc.)
- **Job Change Detection:** Automatically detects when you change jobs and updates available commands
- **Silent Operation:** Works quietly in the background without unnecessary messages
- **Minimal Setup:** No configuration required. Just load and use.


## Installation

1. Download or clone this repository into your Ashita v4 `addons` folder:

   ```
   git clone https://github.com/seekey13/PetTranslator.git
   ```

2. Start or restart Ashita.
3. Load the addon in-game:

   ```
   /addon load pettranslator
   ```


## Usage

PetTranslator provides three simple commands that work across all pet jobs:

### Basic Commands

```
/pt go [target]    - Attack command (defaults to <t> if no target specified)
/pt stop           - Recall/stop command (always targets <me>)
/pt bye            - Dismiss/release command (always targets <me>)
```

### Examples

```
/pt go             - Attack current target
/pt go <st>        - Attack selected taget
/pt go <bt>        - Attack battle target
/pt stop           - Recall your pet
/pt bye            - Dismiss your pet
```


## Supported Jobs & Abilities

| Job | Go Command | Stop Command | Bye Command |
|-----|------------|--------------|-------------|
| **BST** (Beastmaster) | Fight (Lv. 1) | Heel (Lv. 10) | Leave (Lv. 35) |
| **SMN** (Summoner) | Assault (Lv. 1) | Retreat (Lv. 1) | Release (Lv. 1) |
| **PUP** (Puppetmaster) | Deploy (Lv. 1) | Retrieve (Lv. 10) | Deactivate (Lv. 1) |


## Intelligent Behavior

### Job Detection
- Automatically detects when you're on BST, SMN, or PUP
- Goes dormant on other jobs (commands are silently ignored)
- Announces job changes with current level information

### Level Requirements
- Commands automatically respect level requirements for abilities
- If you're below the required level, commands are silently ignored
- No error spam when abilities aren't available yet

### Smart Targeting
- **Go command:** Accepts any valid target or defaults to `<t>`
- **Stop/Bye commands:** Always use `<me>` for safety


## Output

By default, PetTranslator runs silently and only displays messages when:
- The addon first loads (shows detected job and level)
- You change jobs (shows job transition)

### Status Command
```
/pt
```
Displays your current job and level (or indicates no pet job is active).

### Debug Mode
Enable detailed output with:
```
/pt debug
```

When debug mode is enabled, you'll see:
- Command execution details
- Pet ability names being used
- Target information

> **Example Debug Output:**  
> [PetTranslator] Executing: /pet "Fight" &lt;t&gt;


## Compatibility

- **Ashita v4** (required)
- **Jobs:** Beastmaster, Summoner, Puppetmaster
- **CatsEyeXI** server (designed for)


## License

MIT License. See [LICENSE](LICENSE) for details.


## Credits

- Author: Seekey
- Inspired by the need for consistent pet command syntax across pet jobs.

## Support

Open an issue or pull request on the [GitHub repository](https://github.com/seekey13/PetTranslator) if you have suggestions or encounter problems.

## Special Thanks

[Commandobill](https://github.com/commandobill), [Xenonsmurf](https://github.com/Xenonsmurf), [atom0s](https://github.com/atom0s), and [Carver](https://github.com/CatsEyeXI)

Completely unnecessary AI generated image  
<img width="200" alt="App" src="https://github.com/user-attachments/assets/e3ce85a9-2db0-434c-8930-36d9f83750dd" />

## Changelog

### Version 1.0 (Current)
- Initial release with command translation for BST, SMN, and PUP
- Support for `go`, `stop`, and `bye` commands
- Automatic job detection and change monitoring
- Level-based ability filtering
- Flexible targeting for attack commands
- Debug mode for troubleshooting
