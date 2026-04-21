public with sharing class AgentVerBilhetesUtilizador {

    public class Input {
        @InvocableVariable(label='accountId' required=false)
        public String accountId;

        @InvocableVariable(label='Email (alternativa se ID for vazio)' required=false)
        public String email;

        @InvocableVariable(label='ID da Reserva (ex: 000123)' required=false)
        public String orderName;
    }

    public class Output {
        @InvocableVariable(label='Tem bilhetes?')
        public Boolean temBilhetes;

        @InvocableVariable(label='Total de bilhetes')
        public Decimal totalBilhetes;

        @InvocableVariable(label='Bilhetes (JSON)')
        public String bilhetesJson;

        @InvocableVariable(label='Lista de IDs (Técnico)')
        public List<String> listaIds;

        @InvocableVariable(label='Mensagem formatada para o chat')
        public String mensagemChat;

        @InvocableVariable(label='Erro')
        public String erroMsg;
    }

    @InvocableMethod(
        label       = 'Agente — Ver Bilhetes do Utilizador'
        description = 'Lista todos os bilhetes ativos (estado Vendido) do utilizador autenticado, agrupados por evento.'
        category    = 'GLOBAZ Tickets'
    )
    public static List<Output> verBilhetes(List<Input> inputs) {
        Output out = new Output();
        try {
            Input inp = inputs[0];
            Id targetAccId = String.isNotBlank(inp.accountId) ? (Id) inp.accountId : null;
            String emailSanitized = (inp.email != null) ? inp.email.trim().toLowerCase() : '';

            if (targetAccId == null && String.isNotBlank(emailSanitized)) {
                List<Account> accs = [
                    SELECT Id FROM Account 
                    WHERE PersonEmail = :emailSanitized
                    AND IsPersonAccount = true 
                    LIMIT 1
                ];
                if (!accs.isEmpty()) targetAccId = accs[0].Id;
            }

            // Pesquisa por ID de Reserva (Order Name) se ainda não encontrou nada
            if (targetAccId == null && String.isNotBlank(inp.orderName)) {
                List<Order> ords = [SELECT AccountId FROM Order WHERE Name = :inp.orderName LIMIT 1];
                if (!ords.isEmpty()) targetAccId = ords[0].AccountId;
            }

            if (targetAccId == null) {
                out.temBilhetes = false;
                out.totalBilhetes = 0;
                out.mensagemChat = 'Não consegui encontrar nenhuma compra associada ao email "' + emailSanitized + '". 🧐\n\n'
                    + 'Podes verificar se há algum erro de digitação ou tentar indicar o **ID da Reserva** (ex: 000123)?';
                return new List<Output>{ out };
            }

            // 1. Pesquisa Abrangente: Procura todos os bilhetes 'Vendidos' do utilizador para eventos FUTUROS
            List<Bilhete__c> bilhetes = [
                SELECT Id, Name, Fila__c, NumeroLugar__c, EstadoBilhete__c,
                       Evento__r.Name, Evento__r.DataEvento__c,
                       Evento__r.LocalizacaoEvento__c, Evento__r.Recinto__r.Name,
                       Order__c, Order__r.Name, Order__r.MetodoPagamento__c,
                       CreatedDate
                FROM   Bilhete__c
                WHERE  Account__c       = :targetAccId
                AND    EstadoBilhete__c = 'Vendido'
                AND    Evento__r.DataEvento__c >= TODAY
                ORDER BY Evento__r.DataEvento__c ASC, NumeroLugar__c ASC
            ];

            out.totalBilhetes = bilhetes.size();
            out.temBilhetes   = !bilhetes.isEmpty();

            if (bilhetes.isEmpty()) {
                out.mensagemChat = 'Não encontrei nenhum bilhete ativo para os teus próximos eventos. 🧐';
                out.bilhetesJson = '[]';
                return new List<Output>{ out };
            }

            // 2. Agrupamento por Evento
            Map<String, List<Bilhete__c>> porEvento = new Map<String, List<Bilhete__c>>();
            for (Bilhete__c b : bilhetes) {
                String chave = b.Evento__r.Name;
                if (!porEvento.containsKey(chave)) {
                    porEvento.put(chave, new List<Bilhete__c>());
                }
                porEvento.get(chave).add(b);
            }

            String msg = '🎫 *Encontrei os seguintes bilhetes para os teus próximos eventos:*\n\n';
            List<Map<String, Object>> jsonList = new List<Map<String, Object>>();
            out.listaIds = new List<String>();

            for (String nomeEvento : porEvento.keySet()) {
                List<Bilhete__c> grupo = porEvento.get(nomeEvento);
                Bilhete__c primeiro    = grupo[0];
                String dataStr = primeiro.Evento__r.DataEvento__c != null
                    ? primeiro.Evento__r.DataEvento__c.format() : '';
                String recinto = primeiro.Evento__r.Recinto__r != null
                    ? primeiro.Evento__r.Recinto__r.Name
                    : primeiro.Evento__r.LocalizacaoEvento__c;

                msg += '🎪 *' + nomeEvento + '*\n';
                msg += '   📅 ' + dataStr + ' | 📍 ' + recinto + '\n';

                for (Bilhete__c b : grupo) {
                    msg += '   🎟️ Lugar **' + (Integer) b.NumeroLugar__c + '** (Fila ' + b.Fila__c + ')\n';
                    
                    out.listaIds.add(b.Id);
                    jsonList.add(new Map<String, Object>{
                        'id'         => b.Id,
                        'evento'     => nomeEvento,
                        'data'       => dataStr,
                        'fila'       => b.Fila__c,
                        'lugar'      => b.NumeroLugar__c,
                        'orderId'    => b.Order__c
                    });
                }
                msg += '\n';
            }

            msg += 'Como posso ajudar-te com estes bilhetes? (cancelar, pdf, etc.)';

            out.mensagemChat = msg;
            out.bilhetesJson = JSON.serialize(jsonList);

        } catch (Exception e) {
            out.erroMsg      = e.getMessage();
            out.mensagemChat = 'Não consegui carregar os teus bilhetes. Tenta novamente.';
            out.temBilhetes  = false;
        }
        return new List<Output>{ out };
    }
}