public without sharing class AgentCriarReservaAgent {

    public class Input {
        @InvocableVariable(label='ID do Evento' required=true)
        public String eventoId;

        @InvocableVariable(label='ID do Account (null se guest)' required=false)
        public String accountId;

        @InvocableVariable(label='Método de pagamento' required=true)
        public String metodoPagamento;

        @InvocableVariable(label='Nome completo (obrigatório se guest)' required=false)
        public String nomeCompleto;

        @InvocableVariable(label='Email (obrigatório se guest)' required=false)
        public String email;
    }

    public class Output {
        @InvocableVariable(label='Order ID criada')
        public String orderId;

        @InvocableVariable(label='Sucesso?')
        public Boolean sucesso;

        @InvocableVariable(label='Mensagem para o chat')
        public String mensagemChat;

        @InvocableVariable(label='Erro')
        public String erroMsg;
    }

    @InvocableMethod(
        label       = 'Agente — Criar Reserva'
        description = 'Cria uma Order Draft para o evento selecionado, após confirmação do utilizador. Faz o callout HTTP ao gateway de pagamento.'
        category    = 'GLOBAZ Tickets'
    )
    public static List<Output> criarReserva(List<Input> inputs) {
        Output out = new Output();
        try {
            Input inp = inputs[0];

            Id evId  = (Id) inp.eventoId;
            Id accId = String.isNotBlank(inp.accountId) ? (Id) inp.accountId : null;

            // Reutilizar lógica existente do BilheteiraController
            String resultado = BilheteiraController.criarReserva(
                evId,
                accId,
                inp.metodoPagamento,
                inp.nomeCompleto,
                inp.email
            );

            if (resultado == 'PAGAMENTO_RECUSADO') {
                out.sucesso      = false;
                out.erroMsg      = 'PAGAMENTO_RECUSADO';
                out.mensagemChat = '❌ O pagamento foi recusado pelo sistema. '
                    + 'Queres tentar com outro método de pagamento?';
                return new List<Output>{ out };
            }

            if (resultado.startsWith('ERRO:')) {
                out.sucesso      = false;
                out.erroMsg      = resultado;
                out.mensagemChat = '⚠️ Ocorreu um erro: ' + resultado.replace('ERRO: ', '')
                    + '\nTenta novamente ou contacta o suporte.';
                return new List<Output>{ out };
            }

            // Sucesso — resultado é o ID da Order
            out.sucesso      = true;
            out.orderId      = resultado;
            out.mensagemChat = '✅ Reserva criada! A processar o pagamento...';

        } catch (Exception e) {
            out.sucesso      = false;
            out.erroMsg      = e.getMessage();
            out.mensagemChat = '⚠️ Erro inesperado. Por favor tenta novamente.';
        }
        return new List<Output>{ out };
    }
}