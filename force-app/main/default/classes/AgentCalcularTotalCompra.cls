public with sharing class AgentCalcularTotalCompra {

    public class Input {
        @InvocableVariable(label='ID do Evento' required=true)
        public String eventoId;

        @InvocableVariable(label='Tipo de bilhete (BLT-Geral / BLT-VIP / BLT-CAMAROTE)' required=true)
        public String tipoBilhete;

        @InvocableVariable(label='Quantidade de bilhetes' required=true)
        public Integer quantidade;

        @InvocableVariable(label='Extras selecionados (JSON: [{code, qty}])' required=false)
        public String extrasJson;
    }

    public class Output {
        @InvocableVariable(label='Preço unitário do bilhete (s/ IVA)')
        public Decimal precoUnitario;

        @InvocableVariable(label='Subtotal bilhetes (s/ IVA)')
        public Decimal subtotalBilhetes;

        @InvocableVariable(label='Subtotal extras (s/ IVA)')
        public Decimal subtotalExtras;

        @InvocableVariable(label='Valor IVA (23%)')
        public Decimal valorIva;

        @InvocableVariable(label='TOTAL com IVA')
        public Decimal totalComIva;

        @InvocableVariable(label='Resumo formatado para o chat')
        public String resumoChat;

        @InvocableVariable(label='Erro')
        public String erroMsg;
    }

    @InvocableMethod(
        label       = 'Agente — Calcular Total da Compra'
        description = 'Calcula o total de uma compra (bilhetes + extras) com IVA de 23% e devolve resumo para o chat.'
        category    = 'GLOBAZ Tickets'
    )
    public static List<Output> calcularTotal(List<Input> inputs) {
        Output out = new Output();
        try {
            Input inp = inputs[0];
            Id evId   = (Id) inp.eventoId;

            // Buscar preço do tipo de bilhete
            List<Evento__c> evs = [
                SELECT Pricebook__c FROM Evento__c WHERE Id = :evId LIMIT 1
            ];
            if (evs.isEmpty() || evs[0].Pricebook__c == null) {
                out.erroMsg = 'Pricebook não configurado para este evento.';
                return new List<Output>{ out };
            }

            List<PricebookEntry> pbes = [
                SELECT UnitPrice, Product2.ProductCode, Product2.Name
                FROM   PricebookEntry
                WHERE  Pricebook2Id         = :evs[0].Pricebook__c
                AND    Product2.ProductCode = :inp.tipoBilhete
                AND    IsActive             = true
                LIMIT  1
            ];
            if (pbes.isEmpty()) {
                out.erroMsg = 'Tipo de bilhete não disponível: ' + inp.tipoBilhete;
                return new List<Output>{ out };
            }

            out.precoUnitario    = pbes[0].UnitPrice;
            out.subtotalBilhetes = pbes[0].UnitPrice * inp.quantidade;
            out.subtotalExtras   = 0;

            // Processar extras
            String linhasExtras = '';
            if (String.isNotBlank(inp.extrasJson)) {
                List<Object> extras = (List<Object>) JSON.deserializeUntyped(inp.extrasJson);
                for (Object obj : extras) {
                    Map<String, Object> ex = (Map<String, Object>) obj;
                    String code = (String) ex.get('code');
                    Integer qty = Integer.valueOf(String.valueOf(ex.get('qty')));
                    if (qty <= 0) continue;

                    List<PricebookEntry> ep = [
                        SELECT UnitPrice, Product2.Name
                        FROM   PricebookEntry
                        WHERE  Pricebook2Id         = :evs[0].Pricebook__c
                        AND    Product2.ProductCode = :code
                        AND    IsActive             = true
                        LIMIT  1
                    ];
                    if (!ep.isEmpty()) {
                        Decimal subtotalExt = ep[0].UnitPrice * qty;
                        out.subtotalExtras += subtotalExt;
                        linhasExtras += '   ➕ ' + qty + 'x ' + ep[0].Product2.Name
                            + ' — ' + subtotalExt.setScale(2) + '€\n';
                    }
                }
            }

            Decimal subtotalSemIva = out.subtotalBilhetes + out.subtotalExtras;
            out.valorIva   = (subtotalSemIva * 0.23).setScale(2);
            out.totalComIva = (subtotalSemIva * 1.23).setScale(2);

            // Resumo para o chat
            String nomeTipo = inp.tipoBilhete == 'BLT-VIP'      ? 'VIP'
                            : inp.tipoBilhete == 'BLT-CAMAROTE' ? 'Camarote'
                            : 'Geral';

            String msg = '🛒 *Resumo da tua compra:*\n\n';
            msg += '   🎫 ' + inp.quantidade + 'x Bilhete ' + nomeTipo
                + ' — ' + out.subtotalBilhetes.setScale(2) + '€\n';
            if (String.isNotBlank(linhasExtras)) msg += linhasExtras;
            msg += '\n   📊 Subtotal (s/ IVA): ' + subtotalSemIva.setScale(2) + '€\n';
            msg += '   🧾 IVA (23%): '           + out.valorIva               + '€\n';
            msg += '   ─────────────────────\n';
            msg += '   💰 *TOTAL: '              + out.totalComIva            + '€*\n\n';
            msg += 'Posso avançar para o pagamento?';

            out.resumoChat = msg;

        } catch (Exception e) {
            out.erroMsg    = 'Erro ao calcular total: ' + e.getMessage();
            out.resumoChat = 'Ocorreu um erro no cálculo. Tenta novamente.';
        }
        return new List<Output>{ out };
    }
}