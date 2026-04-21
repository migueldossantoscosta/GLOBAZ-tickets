import { LightningElement, api, wire } from 'lwc';
import { getRecord, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import getMetrics from '@salesforce/apex/CrmEventoMetricsController.getMetrics';
import bloquearVendasApex from '@salesforce/apex/CrmEventoMetricsController.bloquearVendas';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CrmPainelEvento extends LightningElement {
    @api recordId;
    
    metrics;
    error;

    @wire(getMetrics, { eventId: '$recordId' })
    wiredMetrics({ error, data }) {
        if (data) {
            this.metrics = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.metrics = undefined;
        }
    }

    get capacidadeTotal() {
        return this.metrics ? this.metrics.capacidadeTotal : 0;
    }

    get bilhetesVendidos() {
        return this.metrics ? this.metrics.bilhetesVendidos : 0;
    }

    get receitaTotal() {
        return this.metrics ? this.metrics.receitaTotal : 0;
    }

    get isEsgotado() {
        return this.metrics ? this.metrics.isEsgotado : false;
    }

    get percentagemLotacao() {
        if (!this.capacidadeTotal || this.capacidadeTotal === 0) return 0;
        return Math.floor((this.bilhetesVendidos / this.capacidadeTotal) * 100);
    }
    
    get lotacaoLabel() {
        return `${this.percentagemLotacao}%`;
    }
    
    get isEsgotadoLabel() {
        return this.isEsgotado ? 'Vendas Bloqueadas' : 'Bloquear Vendas';
    }

    get lotacaoClass() {
        if (this.percentagemLotacao > 90) return 'progress-bar warning';
        return 'progress-bar normal';
    }

    get formattedReceita() {
        return new Intl.NumberFormat('pt-PT', { style: 'currency', currency: 'EUR' }).format(this.receitaTotal);
    }

    renderedCallback() {
        if (this.refs.progressBar) {
            this.refs.progressBar.style.width = this.lotacaoLabel;
        }
    }

    async handleBloquearVendas() {
        try {
            await bloquearVendasApex({ eventId: this.recordId });
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Sucesso',
                    message: 'Vendas bloqueadas com sucesso!',
                    variant: 'success'
                })
            );

            // Forçar atualização do gráfico e do registo
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            // O @wire deve atualizar automaticamente se não for cacheable, 
            // mas como é cacheable, podemos precisar de refreshApex se quisermos instantâneo sem refresh da página.
            // Por simplicidade aqui, o notifyRecordUpdateAvailable ajuda o Salesforce a saber que mudou.
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Erro',
                    message: error.body ? error.body.message : 'Erro desconhecido',
                    variant: 'error'
                })
            );
        }
    }

    handleExportarLista() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Info',
                message: 'A funcionalidade de exportação será implementada na próxima fase.',
                variant: 'info'
            })
        );
    }
}
