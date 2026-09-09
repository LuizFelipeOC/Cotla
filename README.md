# Cotla

App iOS nativo para acompanhar cotações de ações da B3 direto do bolso.

Construído com **UIKit puro, sem Storyboard** — interface 100% programática, pensado desde o início para abraçar o **Liquid Glass** do iOS 26 (ícone com material de vidro nativo, adaptado automaticamente para light, dark e tinted).

> ⚠️ Projeto em estágio inicial — a base do app (target, ícone, delegates) está pronta; a lógica de cotações ainda está sendo construída.

## Stack

- Swift + UIKit (sem Storyboard — `SceneDelegate` monta a `UIWindow` e o `rootViewController` via código)
- Suporte a iPhone e iPad
- Ícone criado no **Icon Composer** (Xcode 26), com efeito de Liquid Glass nativo

## Estrutura atual

```
cotla.app/
├── AppDelegate.swift
├── SceneDelegate.swift      // cria a window e o root view controller na mão
├── ViewController.swift     // tela inicial (placeholder)
└── Assets.xcassets/         // ícone com camadas (Liquid Glass)
```

## Rodando o projeto

1. Abra `cotla.app.xcodeproj` no Xcode
2. Selecione um simulador de iPhone
3. `Cmd+R`

## Roadmap

- [ ] Listagem de ativos da B3 com cotação atualizada
- [ ] Busca de ativos por ticker
- [ ] Integração com API pública de mercado (ex: [brapi.dev](https://brapi.dev))
- [ ] Tela de detalhe do ativo (histórico, variação)
- [ ] Favoritos / acompanhamento persistente

## Licença

Ainda não definida.
