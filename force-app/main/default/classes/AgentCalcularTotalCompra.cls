public without sharing class AgentCalcularTotalCompra {

    public class Input {
        @InvocableVariable(label='ID do Evento' required=true)
        public String eventoId;

        @InvocableVariable(label='Tipo de bilhete (Geral, VIP ou Camarote)' required=true)
        public String tipoBilhete;

        @InvocableVariable(label='Quantidade de bilhetes' required=true)
        public Decimal quantidade;

        @InvocableVariable(label='Extras selecionados (JSON)')
        public String extrasJson;
    }

    public class Output {
        @InvocableVariable(label='TOTAL com IVA')
        public Decimal totalComIva;

        @InvocableVariable(label='Resumo formatado para o chat')
        public String resumoChat;

        @InvocableVariable(label='Erro')
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
                List<PricebookEntry> pbes = [
                    SELECT UnitPrice, Product2.Name 
                    FROM   PricebookEntry 
                    WHERE  Pricebook2Id = :ev.Pricebook__c 
                    AND    (Product2.ProductCode = :codigoGeral OR Product2.Name LIKE :nomeBusca)
                    AND    IsActive = true 
                    LIMIT  1
                ];
                
                if (!pbes.isEmpty()) {
                    precoUnitario = pbes[0].UnitPrice;
                    nomeProdutoDisplay = pbes[0].Product2.Name;
                    encontradoNoPricebook = true;
                }
            }

            // Fallback apenas para bilhete Geral se o Pricebook falhar
            if (!encontradoNoPricebook) {
                if (inp.tipoBilhete.equalsIgnoreCase('Geral') && ev.PrecoBilhete__c != null) {
                    precoUnitario = ev.PrecoBilhete__c;
                    nomeProdutoDisplay = 'Geral';
                } else {
                    out.erroMsg = 'Não foi possível encontrar o preço para "' + inp.tipoBilhete + '" no Pricebook deste evento.';
                    out.resumoChat = 'Desculpa, não encontrei o preço para o tipo "' + inp.tipoBilhete + '". Confirma se é Geral, VIP ou Camarote?';
                    return new List<Output>{ out };
                }
            }

            // 3. Calcular Total de Bilhetes (IVA 23%)
            out.totalComIva = (precoUnitario * 1.23 * inp.quantidade).setScale(2);
            String itensSelecionados = '🎫 ' + inp.quantidade.setScale(0) + 'x ' + nomeProdutoDisplay + ': ' + out.totalComIva + '€\n';

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
            String msg = '🛒 *Resumo da tua seleção:*\n\n' +
                         itensSelecionados +
                         '\n💰 *TOTAL FINAL (c/ IVA): ' + out.totalComIva + '€*\n\n' +
                         'Posso avançar com a reserva?';

            out.resumoChat = msg;

        } catch (Exception e) {
            out.erroMsg = 'Erro: ' + e.getMessage();
            out.resumoChat = 'Ocorreu um erro no cálculo. Tenta novamente.';
        }
        return new List<Output>{ out };
    }
}