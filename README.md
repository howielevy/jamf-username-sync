# JAMF Username Sync (SetUserAndLocation-v5.0.sh)

This script automatically updates the logged-in macOS user's **Jamf Pro user record** with their corporate email address and triggers **Okta directory enrichment** for title, department, and location data.

### Features
- Detects the logged-in user and normalizes to email format
- Uses secure **OAuth API tokens** (no plaintext passwords)
- Updates the Jamf user via `jamf recon`
- Verifies the change and invalidates the token automatically
- Fully compatible with macOS 15 / 26 and Jamf Pro 11.9+

### Parameters
| Parameter | Description | Example |
|------------|--------------|---------|
| `$4` | Jamf Pro URL | `https://yourcompany.jamfcloud.com` |
| `$5` | API Client ID | `abcdef12-3456-7890-ghij-klmnopqrstuv` |
| `$6` | API Client Secret | `yourClientSecretHere` |

### Example Use in Jamf
- Create a script in Jamf Pro with this content  
- Configure parameters `$4`, `$5`, and `$6`  
- Add to your **Login Policy** or **Enrollment Complete** workflow

### License
MIT License © 2025 Howard Levy
