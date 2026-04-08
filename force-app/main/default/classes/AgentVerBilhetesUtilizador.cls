public with sharing class AgentVerBilhetesUtilizador {

    public class Input {
        @InvocableVariable(label='Account ID do utilizador' required=true)
        public String accountId;
    }

    public class Output {
        @InvocableVariable(label='Tem bilhetes?')
        public Boolean temBilhetes;

        @InvocableVariable(label='Total de bilhetes')
        public Decimal totalBilhetes;

        @InvocableVariable(label='Bilhetes (JSON)')
        public String bilhetesJson;

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
            Id accId = (Id) inputs[0].accountId;

            List<Bilhete__c> bilhetes = [
                SELECT Id, Name, Fila__c, NumeroLugar__c, EstadoBilhete__c,
                       Evento__r.Name, Evento__r.DataEvento__c,
                       Evento__r.LocalizacaoEvento__c, Evento__r.Recinto__r.Name,
                       Order__r.Name, Order__r.MetodoPagamento__c,
                       CreatedDate
                FROM   Bilhete__c
                WHERE  Account__c       = :accId
                AND    EstadoBilhete__c = 'Vendido'
                ORDER BY Evento__r.DataEvento__c ASC
                LIMIT  20
            ];

            out.totalBilhetes = bilhetes.size();
            out.temBilhetes   = !bilhetes.isEmpty();

            if (bilhetes.isEmpty()) {
                out.mensagemChat = 'Não tens bilhetes ativos de momento. '
                    + 'Queres que te mostre eventos disponíveis? 🎵';
                out.bilhetesJson = '[]';
                return new List<Output>{ out };
            }

            // Agrupar por evento
            Map<String, List<Bilhete__c>> porEvento = new Map<String, List<Bilhete__c>>();
            for (Bilhete__c b : bilhetes) {
                String chave = b.Evento__r.Name;
                if (!porEvento.containsKey(chave)) {
                    porEvento.put(chave, new List<Bilhete__c>());
                }
                porEvento.get(chave).add(b);
            }

            String msg = '🎫 *Os teus bilhetes:*\n\n';
            List<Map<String, Object>> jsonList = new List<Map<String, Object>>();

            for (String nomeEvento : porEvento.keySet()) {
                List<Bilhete__c> grupo = porEvento.get(nomeEvento);
                Bilhete__c primeiro    = grupo[0];
                String dataStr = primeiro.Evento__r.DataEvento__c != null
                    ? primeiro.Evento__r.DataEvento__c.format() : '';
                String recinto = primeiro.Evento__r.Recinto__r != null
                    ? primeiro.Evento__r.Recinto__r.Name
                    : primeiro.Evento__r.LocalizacaoEvento__c;

                msg += '🎪 *' + nomeEvento + '*\n';
                msg += '   📅 ' + dataStr + '\n';
                msg += '   📍 ' + recinto + '\n';

                for (Bilhete__c b : grupo) {
                    msg += '   🎟️ ' + b.Name + ' — Fila ' + b.Fila__c
                        + ', Lugar ' + (Integer) b.NumeroLugar__c + '\n';
                    jsonList.add(new Map<String, Object>{
                        'id'         => b.Id,
                        'nome'       => b.Name,
                        'evento'     => nomeEvento,
                        'data'       => dataStr,
                        'fila'       => b.Fila__c,
                        'lugar'      => b.NumeroLugar__c,
                        'orderId'    => (b.Order__r != null ? b.Order__r.Name : null),
                        'pagamento'  => (b.Order__r != null ? b.Order__r.MetodoPagamento__c : null)
                    });
                }
                msg += '\n';
            }

            msg += 'Precisas de alguma ajuda com estes bilhetes? '
                + '(reenviar PDF, cancelar, etc.)';

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