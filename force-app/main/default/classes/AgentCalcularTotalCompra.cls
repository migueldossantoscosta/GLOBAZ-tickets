public without sharing class AgentCalcularTotalCompra {

    public class Input {
        @InvocableVariable(label='eventoId' required=true)
        public String eventoId;

        @InvocableVariable(label='tipoBilhete' required=true)
        public String tipoBilhete;

        @InvocableVariable(label='quantidade' required=true)
        public Integer quantidade;

        @InvocableVariable(label='extrasJson')
        public String extrasJson;
    }

    public class Output {
        @InvocableVariable(label='totalComIva')
        public Decimal totalComIva;

        @InvocableVariable(label='resumoChat')
        public String resumoChat;

        @InvocableVariable(label='erroMsg')
        public String erroMsg;
    }

    @InvocableMethod(
        label       = 'Agente — Calcular Total da Compra'
        description = 'Calcula o total da compra consultando o Pricebook do evento para garantir preços atualizados.'
        category    = 'GLOBAZ Tickets'
    )
    public static List<Output> calcularTotal(List<Input> inputs) {
        Output out = new Output();
        try {
            Input inp = inputs[0];
            
            // --- TRADUÇÃO DO TIPO DE BILHETE ---
            String nomeBusca = '%' + inp.tipoBilhete + '%';
            String codigoGeral = 'BLT-Geral';
            if (inp.tipoBilhete.equalsIgnoreCase('Geral'))    codigoGeral = 'BLT-Geral';
            else if (inp.tipoBilhete.equalsIgnoreCase('VIP'))  codigoGeral = 'BLT-VIP';
            else if (inp.tipoBilhete.equalsIgnoreCase('Camarote')) codigoGeral = 'BLT-CAMAROTE';

            // 1. Buscar o Evento
            List<Evento__c> evs = [SELECT Id, Pricebook__c, PrecoBilhete__c FROM Evento__c WHERE Id = :inp.eventoId LIMIT 1];
            if (evs.isEmpty()) {
                out.erroMsg = 'Evento não encontrado.';
                return new List<Output>{ out };
            }
            Evento__c ev = evs[0];

            // 2. Tentar buscar no Pricebook (Prioridade absoluta)
            Decimal precoUnitario = 0;
            String nomeProdutoDisplay = inp.tipoBilhete;
            Boolean encontradoNoPricebook = false;

            if (ev.Pricebook__c != null) {
                for (PricebookEntry pbe : [
                    SELECT UnitPrice, Product2.Name, Product2.ProductCode 
                    FROM   PricebookEntry 
                    WHERE  Pricebook2Id = :ev.Pricebook__c 
                    AND    IsActive = true
                ]) {
                    String nome = pbe.Product2.Name.toLowerCase();
                    String code = (pbe.Product2.ProductCode != null ? pbe.Product2.ProductCode.toLowerCase() : '');
                    String busca = inp.tipoBilhete.toLowerCase();

                    if (nome.contains(busca) || code.contains(busca) || 
                       (busca == 'geral' && (code.contains('geral') || nome.contains('geral'))) ||
                       (busca == 'vip' && (code.contains('vip') || nome.contains('vip'))) ||
                       (busca == 'camarote' && (code.contains('camarote') || nome.contains('camarote')))) {
                        
                        precoUnitario = pbe.UnitPrice;
                        nomeProdutoDisplay = pbe.Product2.Name;
                        encontradoNoPricebook = true;
                        break;
                    }
                }
            }

            // Fallback apenas para bilhete Geral se o Pricebook falhar ou não existir
            if (!encontradoNoPricebook) {
                if ((inp.tipoBilhete.equalsIgnoreCase('Geral') || inp.tipoBilhete.toLowerCase().contains('geral')) && ev.PrecoBilhete__c != null) {
                    precoUnitario = ev.PrecoBilhete__c;
                    nomeProdutoDisplay = 'Geral';
                } else {
                    out.erroMsg = 'Não foi possível encontrar o preço para "' + inp.tipoBilhete + '" no Pricebook deste evento.';
                    out.resumoChat = 'Desculpa, não encontrei o preço para o tipo "' + inp.tipoBilhete + '". Os tipos disponíveis são Geral, VIP ou Camarote.';
                    return new List<Output>{ out };
                }
            }

            // 3. Calcular Total de Bilhetes (IVA 23%)
            out.totalComIva = (precoUnitario * 1.23 * inp.quantidade).setScale(2);
            String itensSelecionados = '🎫 ' + inp.quantidade + 'x ' + nomeProdutoDisplay + ': ' + out.totalComIva + '€\n';

            // 4. Calcular Extras
            if (String.isNotBlank(inp.extrasJson) && inp.extrasJson != '[]') {
                try {
                    List<Object> rawExtras = (List<Object>) JSON.deserializeUntyped(inp.extrasJson);
                    for (Object obj : rawExtras) {
                        Map<String, Object> extra = (Map<String, Object>) obj;
                        Decimal preco = (extra.get('preco') != null) ? Decimal.valueOf(String.valueOf(extra.get('preco'))) : 0;
                        Decimal qtd = (extra.get('qty') != null) ? Decimal.valueOf(String.valueOf(extra.get('qty'))) : 1;
                        String nome = (String) extra.get('nome');
                        
                        Decimal totalExtra = (preco * qtd).setScale(2);
                        out.totalComIva += totalExtra;
                        itensSelecionados += '✨ ' + (Integer)qtd.intValue() + 'x ' + nome + ': ' + totalExtra + '€\n';
                    }
                } catch (Exception parseEx) {
                    // Ignora extras mal formatados
                }
            }

            // 5. Mensagem
            String idLimpo = String.valueOf(ev.Id);
            String mapUrl = 'https://orgfarm-64aee8f1dd-dev-ed.develop.my.site.com/globaztickets/EscolherLugar?idEvento=' + idLimpo;

            String msg = '🛒 *Resumo da tua seleção:*\n\n' +
                         itensSelecionados +
                         '\n📍 [🗺️ Ver Mapa de Lugares e Escolher Assento](' + mapUrl + ')' +
                         '\n\n💰 *TOTAL FINAL (c/ IVA): ' + out.totalComIva + '€*';

            out.resumoChat = msg;

        } catch (Exception e) {
            out.erroMsg = 'Erro: ' + e.getMessage();
            out.resumoChat = 'Ocorreu um erro no cálculo. Tenta novamente.';
        }
        return new List<Output>{ out };
    }
}