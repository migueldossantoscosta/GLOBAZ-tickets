import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

import RECENTO_OBJECT from '@salesforce/schema/Evento__c';
import VENUE_CAPACITY_FIELD from '@salesforce/schema/Recinto__c.LotacaoMaxima__c';

import EVENT_NAME_FIELD from '@salesforce/schema/Evento__c.Name';
import EVENT_VENUE_FIELD from '@salesforce/schema/Evento__c.Recinto__c';
import EVENT_DATE_FIELD from '@salesforce/schema/Evento__c.DataEvento__c';
import EVENT_END_DATE_FIELD from '@salesforce/schema/Evento__c.DataFimEvento__c';
import EVENT_PRICEBOOK_FIELD from '@salesforce/schema/Evento__c.PriceBook__c';
import EVENT_CAPACITY_FIELD from '@salesforce/schema/Evento__c.CapacidadeMaxima__c';
import EVENT_STATUS_FIELD from '@salesforce/schema/Evento__c.EstadoEvento__c';
import EVENT_TYPE_FIELD from '@salesforce/schema/Evento__c.TipoEvento__c';
import EVENT_IMAGE_FIELD from '@salesforce/schema/Evento__c.URLImagem__c';
import EVENT_DESCRIPTION_FIELD from '@salesforce/schema/Evento__c.DescricaoDetalhada__c';

export default class CrmCriarEventoRecinto extends NavigationMixin(LightningElement) {
    @api recordId; // Venue record ID

    eventObject = RECENTO_OBJECT;
    
    // Explicit field references for the template
    fields = {
        name: EVENT_NAME_FIELD,
        venue: EVENT_VENUE_FIELD,
        date: EVENT_DATE_FIELD,
        endDate: EVENT_END_DATE_FIELD,
        pricebook: EVENT_PRICEBOOK_FIELD,
        capacity: EVENT_CAPACITY_FIELD,
        status: EVENT_STATUS_FIELD,
        type: EVENT_TYPE_FIELD,
        image: EVENT_IMAGE_FIELD,
        description: EVENT_DESCRIPTION_FIELD
    };

    @wire(getRecord, { recordId: '$recordId', fields: [VENUE_CAPACITY_FIELD] })
    venue;

    get defaultCapacity() {
        return getFieldValue(this.venue.data, VENUE_CAPACITY_FIELD);
    }

    handleSuccess(event) {
        const toastEvent = new ShowToastEvent({
            title: 'Evento criado',
            message: 'O evento foi criado com sucesso. ID: ' + event.detail.id,
            variant: 'success'
        });
        this.dispatchEvent(toastEvent);

        // Navigate to the new event record
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.detail.id,
                objectApiName: 'Evento__c',
                actionName: 'view'
            }
        });
    }

    handleError(event) {
        const toastEvent = new ShowToastEvent({
            title: 'Erro ao criar evento',
            message: event.detail.message,
            variant: 'error'
        });
        this.dispatchEvent(toastEvent);
    }

    handleCancel() {
        // Close or reset logic could go here
    }
}