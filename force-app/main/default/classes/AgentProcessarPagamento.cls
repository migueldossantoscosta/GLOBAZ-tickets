public without sharing class AgentProcessarPagamento {

    public class Input {
        @InvocableVariable(label='Order ID' required=true)
        public String orderId;

        @InvocableVariable(label='ID do Evento' required=true)
        public String eventoId;

        @InvocableVariable(label='Bilhetes (JSON: [{fila, lugar, tipo, stand}])' required=true)
        public String bilhetesJson;

        @InvocableVariable(label='Extras (JSON: [{pbeId, qty}])' required=false)
        public String extrasJson;
    }

    public class Output {
        @InvocableVariable(label='Sucesso?')
        public Boolean sucesso;

        @InvocableVariable(label='Mensagem para o chat')
        public String mensagemChat;

        @InvocableVariable(label='Número de bilhetes criados')
        public Decimal totalBilhetes;

        @InvocableVariable(label='Erro')
        public String erroMsg;
    }

    @InvocableMethod(
        label       = 'Agente — Processar Pagamento e Criar Bilhetes'
        description = 'Confirma o pagamento com o gateway, cria os Bilhete__c e ativa a Order. Deve ser chamado após AgentCriarReservaAgent.'
        category    = 'GLOBAZ Tickets'
    )
    public static List<Output> processarPagamento(List<Input> inputs) {
        Output out = new Output();
        try {
            Input inp = inputs[0];

            Id ordId = (Id) inp.orderId;
            Id evId  = (Id) inp.eventoId;

            // Bilhetes: se o agente não recebeu fila/lugar específicos
            // (o utilizador selecionou no mapa), usa um JSON default com lugar automático
            String bilhetesJsonFinal = String.isNotBlank(inp.bilhetesJson)
                ? inp.bilhetesJson
                : '[{"fila":"A","lugar":1,"tipo":"BLT-Geral","stand":null}]';

            String extrasJsonFinal = String.isNotBlank(inp.extrasJson)
                ? inp.extrasJson : '[]';

            // Reutilizar lógica existente
            String resultado = BilheteiraController.processarPagamentoMock(
                ordId,
                evId,
                bilhetesJsonFinal,
                extrasJsonFinal
            );

            if (resultado == 'PAGAMENTO_OK') {
                // Contar bilhetes criados
                Integer qtd = [
                    SELECT COUNT() FROM Bilhete__c WHERE Order__c = :ordId
                ];
                out.sucesso       = true;
                out.totalBilhetes = qtd;

                // Buscar email do cliente para confirmar envio
                List<Order> ords = [
                    SELECT Account.PersonEmail, Account.FirstName
                    FROM   Order WHERE Id = :ordId LIMIT 1
                ];
                String emailCliente = (!ords.isEmpty() && ords[0].Account != null)
                    ? ords[0].Account.PersonEmail : '';
                String nomeCliente = (!ords.isEmpty() && ords[0].Account != null)
                    ? ords[0].Account.FirstName : 'Cliente';

                out.mensagemChat =
                    '🎉 *Compra confirmada, ' + nomeCliente + '!*\n\n'
                    + '🎫 ' + qtd + ' bilhete(s) reservado(s) com sucesso.\n'
                    + '📧 O teu bilhete PDF vai chegar ao email *' + emailCliente + '* em breve.\n\n'
                    + '📱 Guarda o email — precisas dele na entrada do evento.\n'
                    + 'Posso ajudar-te com mais alguma coisa? 😊';

            } else if (resultado == 'PAGAMENTO_RECUSADO') {
                out.sucesso      = false;
                out.erroMsg      = 'PAGAMENTO_RECUSADO';
                out.mensagemChat = '❌ O pagamento foi recusado.\n'
                    + 'Queres tentar com outro método? (MBWay, Cartão, MB, Transferência)';

            } else {
                out.sucesso      = false;
                out.erroMsg      = resultado;
                out.mensagemChat = '⚠️ Erro no processamento: '
                    + resultado.replace('ERRO: ', '')
                    + '\nContacta o suporte se o problema persistir.';
            }

        } catch (Exception e) {
            out.sucesso      = false;
            out.erroMsg      = e.getMessage();
            out.mensagemChat = '⚠️ Erro inesperado no pagamento. Tenta novamente.';
        }
        return new List<Output>{ out };
    }
}