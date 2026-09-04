# RJP Cleaner — instalação gratuita com AltStore / SideStore

Esta via serve para instalar o **RJP Cleaner** num iPhone sem pagar o Apple Developer Program.

## O que o GitHub passa a gerar

Executa o workflow:

`Actions → iOS Unsigned IPA (AltStore-SideStore) → Run workflow`

No fim, abre o job e descarrega o Artifact:

`RJP-Cleaner-iOS-Unsigned-IPA`

Dentro do ZIP do Artifact tens:

- `RJP-Cleaner-Unsigned.ipa`
- `RJP-Cleaner-Unsigned.ipa.sha256`

O `.ipa` é deliberadamente **não assinado**. AltStore Classic ou SideStore assinam-no com a tua Apple Account gratuita quando o instalas.

---

## Via A — SideStore

A SideStore é a opção mais cómoda depois da configuração inicial porque consegue renovar apps no próprio iPhone.

1. Instala a SideStore seguindo a documentação oficial.
2. No iPhone, ativa o modo de programador se for pedido.
3. Liga o `LocalDevVPN` quando fores instalar, atualizar ou renovar apps.
4. Abre a SideStore e inicia sessão com a Apple Account usada na instalação.
5. Abre `My Apps`.
6. Usa o botão `+` / importar e escolhe `RJP-Cleaner-Unsigned.ipa` na app Ficheiros.
7. A SideStore assina e instala o RJP Cleaner.
8. Antes de expirarem os 7 dias, usa `Refresh` na SideStore.

Com Apple Account gratuita, a Apple limita normalmente a assinatura a 7 dias e a 3 apps ativas ao mesmo tempo, contando a própria SideStore.

---

## Via B — AltStore Classic

1. Instala o AltServer no computador e usa-o para instalar o AltStore Classic no iPhone.
2. Mantém o iPhone e o computador na mesma rede quando precisares de renovar.
3. No iPhone, abre o AltStore.
4. Em `My Apps`, toca em `+`.
5. Escolhe `RJP-Cleaner-Unsigned.ipa` na app Ficheiros.
6. O AltStore assina e instala a app com a tua Apple Account gratuita.
7. Renova a app antes do prazo de 7 dias.

---

## Atualizar o RJP Cleaner sem perder dados

Quando houver uma versão nova:

1. Corre novamente o workflow `iOS Unsigned IPA (AltStore-SideStore)`.
2. Descarrega o novo `.ipa`.
3. Instala-o por cima da versão existente usando SideStore/AltStore.
4. Não apagues primeiro a app, para preservar os dados locais sempre que o iOS permitir.

O Bundle ID continua a ser:

`pt.rjp.cleaner.ios`

---

## Importante

- Esta via não usa TestFlight.
- Não são necessários os 7 GitHub Secrets da Apple.
- Não exige subscrição paga do Apple Developer Program.
- O GitHub gera o IPA, mas a assinatura final é feita no teu iPhone pelo SideStore/AltStore.
- A renovação periódica é uma limitação da conta Apple gratuita, não do RJP Cleaner.
