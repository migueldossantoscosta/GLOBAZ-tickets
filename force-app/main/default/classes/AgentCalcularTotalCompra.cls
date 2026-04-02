public with sharing class AgentCalcularTotalCompra {

    public class Input {
        @InvocableVariable(label='ID do Evento' required=true)
        public String eventoId;

        @InvocableVariable(label='Tipo de bilhete (Geral, VIP ou Camarote)' required=true)
        public String tipoBilhete;

        @InvocableVariable(label='Quantidade de bilhetes' required=true)
        public Decimal quantidade; // Mantido Decimal para o Agentforce

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
        description = 'Calcula o total da compra convertendo nomes amigáveis para códigos de produto.'
        category    = 'GLOBAZ Tickets'
    )
    public static List<Output> calcularTotal(List<Input> inputs) {
        Output out = new Output();
        try {
            Input inp = inputs[0];
            
            // --- TRADUÇÃO DO TIPO DE BILHETE ---
            // Se o bot mandar "Geral", nós convertemos para "BLT-Geral"
            String codigoProcurado = inp.tipoBilhete;
            if (codigoProcurado.equalsIgnoreCase('Geral'))    codigoProcurado = 'BLT-Geral';
            else if (codigoProcurado.equalsIgnoreCase('VIP'))  codigoProcurado = 'BLT-VIP';
            else if (codigoProcurado.equalsIgnoreCase('Camarote')) codigoProcurado = 'BLT-CAMAROTE';
            // Se o bot já mandar o código certo (BLT-...), ele ignora os IFs acima.

            List<Evento__c> evs = [SELECT Pricebook__c FROM Evento__c WHERE Id = :inp.eventoId LIMIT 1];
            if (evs.isEmpty() || evs[0].Pricebook__c == null) {
                out.erroMsg = 'Evento ou Pricebook não encontrado.';
                return new List<Output>{ out };
            }

            // Buscar o preço usando o código "traduzido"
            List<PricebookEntry> pbes = [
                SELECT UnitPrice, Product2.Name 
                FROM   PricebookEntry 
                WHERE  Pricebook2Id = :evs[0].Pricebook__c 
                AND    (Product2.ProductCode = :codigoProcurado OR Product2.Name = :inp.tipoBilhete)
                AND    IsActive = true 
                LIMIT  1
            ];

            if (pbes.isEmpty()) {
                out.erroMsg = 'Tipo de bilhete não disponível: ' + inp.tipoBilhete;
                out.resumoChat = 'Desculpa, não encontrei o tipo de bilhete "' + inp.tipoBilhete + '". Queres tentar Geral, VIP ou Camarote?';
                return new List<Output>{ out };
            }

            Decimal precoUnitario = pbes[0].UnitPrice;
            Decimal subtotalBilhetes = precoUnitario * inp.quantidade;
            
            // Cálculo do IVA (23%)
            out.totalComIva = (subtotalBilhetes * 1.23).setScale(2);

            // --- MENSAGEM PARA O CHAT ---
            String msg = '🛒 *Resumo da tua seleção:*\n\n';
            msg += '🎫 ' + inp.quantidade.setScale(0) + 'x Bilhete ' + pbes[0].Product2.Name + '\n';
            msg += '💰 *TOTAL (c/ IVA): ' + out.totalComIva + '€*\n\n';
            msg += 'Posso avançar com a reserva destes lugares?';

            out.resumoChat = msg;

        } catch (Exception e) {
            out.erroMsg = 'Erro: ' + e.getMessage();
            out.resumoChat = 'Ocorreu um erro ao calcular o preço. Podes tentar novamente?';
        }
        return new List<Output>{ out };
    }
}