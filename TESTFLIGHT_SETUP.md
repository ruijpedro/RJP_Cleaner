# RJP Cleaner — configuração GitHub → TestFlight

A V1.3.1 inclui o workflow **iOS TestFlight**. Ele só corre manualmente (`workflow_dispatch`) e faz:

1. gera o projeto Xcode com XcodeGen;
2. instala temporariamente o certificado Apple Distribution;
3. instala o provisioning profile App Store;
4. cria um Archive Release assinado;
5. exporta o `.ipa`;
6. publica o `.ipa` em GitHub **Artifacts** por 14 dias;
7. envia o mesmo `.ipa` para **App Store Connect / TestFlight**.

## 1. Pré-requisitos Apple

É necessária uma subscrição ativa do **Apple Developer Program** e a app `pt.rjp.cleaner.ios` criada/configurada na conta Apple.

No portal Apple Developer, prepara:

- um certificado **Apple Distribution** exportado do Keychain como `.p12`;
- um **App Store Connect provisioning profile** para `pt.rjp.cleaner.ios`;
- o **Team ID**.

No App Store Connect cria uma **API Key** com acesso suficiente para carregar builds. Guarda:

- Key ID;
- Issuer ID;
- ficheiro privado `AuthKey_XXXXXXXXXX.p8` (só pode ser descarregado uma vez).

## 2. Converter os 3 ficheiros para Base64

No macOS:

```bash
base64 -i RJP_Distribution.p12 | pbcopy
base64 -i RJP_Cleaner_AppStore.mobileprovision | pbcopy
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

No Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("RJP_Distribution.p12")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("RJP_Cleaner_AppStore.mobileprovision")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXXXXXXXX.p8")) | Set-Clipboard
```

## 3. Criar GitHub Secrets

No repositório:

**Settings → Secrets and variables → Actions → New repository secret**

Cria exatamente estes secrets:

| Secret | Conteúdo |
|---|---|
| `APPLE_CERTIFICATE_BASE64` | `.p12` convertido para Base64 |
| `APPLE_CERTIFICATE_PASSWORD` | palavra-passe usada ao exportar o `.p12` |
| `APPLE_PROVISIONING_PROFILE_BASE64` | `.mobileprovision` em Base64 |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `ASC_KEY_ID` | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | App Store Connect Issuer ID |
| `ASC_API_KEY_BASE64` | `AuthKey_....p8` em Base64 |

O workflow nunca grava estes segredos no repositório. O keychain criado no runner é temporário e é apagado no fim.

## 4. Primeira execução

No GitHub:

**Actions → iOS TestFlight → Run workflow → main → Run workflow**

Quando terminar com ✅:

- em **Artifacts** aparece `RJP-Cleaner-iOS-IPA`;
- em **App Store Connect → TestFlight** o build começa a ser processado pela Apple.

## 5. Partilhar com iPhone

Depois de o build estar disponível no TestFlight:

- **Teste interno:** adiciona membros da equipa App Store Connect; não exige beta review para os testers internos suportados pela Apple.
- **Teste externo:** cria um grupo de testers externos, submete o primeiro build à Beta App Review quando pedido e depois ativa **Public Link** para obter um link partilhável.

O link partilhável é criado pela Apple no **TestFlight**, não pelo GitHub.

## 6. Novos builds

A Apple exige um número de build (`CURRENT_PROJECT_VERSION`) novo a cada upload. A V1.3.1 está configurada como:

- versão: `1.3.1`
- build: `4`

Antes de enviar outro build com a mesma versão, aumenta `CURRENT_PROJECT_VERSION` em `iOS/project.yml` (5, 6, 7...).
